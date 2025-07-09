#!/bin/bash

# Load secrets and configuration from .env in the same folder
ENV_FILE="$(dirname "$0")/.env"
if [ -f "$ENV_FILE" ]; then
  source "$ENV_FILE"
else
  echo "$(date '+%F %T') [ERROR] .env file not found at $ENV_FILE" >&2
  exit 1
fi

# Logging setup
LOGFILE="$(dirname "$0")/logs/system_status.log"
mkdir -p "$(dirname "$LOGFILE")"
exec >> "$LOGFILE" 2>&1

echo "$(date '+%F %T') [INFO] Running system status script"

# Dependencies
HOSTNAME=$(hostname)
CURL=$(which curl)
WHO=$(which who)
WC=$(which wc)
UPTIME=$(which uptime)
AWK=$(which awk)
FREE=$(which free)
DF=$(which df)
UNAME=$(which uname)
MSMTP=$(which msmtp)

# Check dependencies
for BIN in $CURL $WHO $WC $UPTIME $AWK $FREE $DF $UNAME $MSMTP; do
  if [ ! -x "$BIN" ]; then
    echo "$(date '+%F %T') [ERROR] Dependency $BIN missing!" >&2
    exit 2
  fi
done

# Accurate CPU usage (1-second sampling)
cpu_idle_1=$(awk '/^cpu / {print $5}' /proc/stat)
cpu_total_1=$(awk '/^cpu / {print $2+$3+$4+$5+$6+$7+$8}' /proc/stat)
sleep 1
cpu_idle_2=$(awk '/^cpu / {print $5}' /proc/stat)
cpu_total_2=$(awk '/^cpu / {print $2+$3+$4+$5+$6+$7+$8}' /proc/stat)
cpu_idle_diff=$((cpu_idle_2 - cpu_idle_1))
cpu_total_diff=$((cpu_total_2 - cpu_total_1))
if [ "$cpu_total_diff" -gt 0 ]; then
  cpu_usage=$((100 * (cpu_total_diff - cpu_idle_diff) / cpu_total_diff))
else
  cpu_usage=0
fi

# Gather System Info
PUBLIC_IP=$($CURL -s https://ipv4.icanhazip.com)
USERS=$($WHO | $WC -l)
UPTIME_INFO=$($UPTIME -p)
MEMORY=$($FREE -h | $AWK '/Mem:/ {print $3 " used of " $2}')
DISK=$($DF -h / | $AWK 'NR==2 {print $5 " used on " $6}')
LOAD=$($UPTIME | $AWK -F'load average:' '{ print $2 }' | xargs)
SWAP=$($FREE -h | $AWK '/Swap:/ {print $3 " used of " $2}')
KERNEL=$($UNAME -r)
ARCH=$($UNAME -m)

# Build Telegram Message
MESSAGE=$(cat <<EOF
🔔 Server Status Report

🖥️  Host: \`$HOSTNAME\`
🌐 Public IP: \`$PUBLIC_IP\`
👤 Logged-In Users: \`$USERS\`
🕒 Uptime: \`$UPTIME_INFO\`
🚀 CPU Usage: \`$cpu_usage%\`
🧠 Memory: \`$MEMORY\`
💾 Disk: \`$DISK\`
📈 Load Avg: \`$LOAD\`
🔃 Swap: \`$SWAP\`
⚙️  Arch: \`$ARCH\`
🔧 Kernel: \`$KERNEL\`
EOF
)

# Send to Telegram
TELEGRAM_RESPONSE=$($CURL -s -X POST "https://api.telegram.org/bot$TELEGRAM_BOT_TOKEN/sendMessage" \
  -d "chat_id=$TELEGRAM_CHAT_ID" \
  --data-urlencode "text=$MESSAGE" \
  -d "parse_mode=Markdown")
if ! echo "$TELEGRAM_RESPONSE" | grep -q '"ok":true'; then
  echo "$(date '+%F %T') [ERROR] Failed to send Telegram message: $TELEGRAM_RESPONSE"
fi

# Email configuration
RAW_SUBJECT="Server Status Report - $HOSTNAME"
ENCODED_SUBJECT=$(echo -n "$RAW_SUBJECT" | base64)
EMAIL_SUBJECT="=?UTF-8?B?$ENCODED_SUBJECT?="

# Send email via msmtp with UTF-8 headers
$MSMTP "$EMAIL_TO" <<EOF
From: $EMAIL_FROM
To: $EMAIL_TO
Subject: $EMAIL_SUBJECT
Content-Type: text/plain; charset=UTF-8

$MESSAGE
EOF

if [ $? -ne 0 ]; then
  echo "$(date '+%F %T') [ERROR] Failed to send email via msmtp"
fi
