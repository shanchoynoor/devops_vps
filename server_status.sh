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

# Use Bangladesh time (UTC+6) for all timestamps in this script
export TZ='Asia/Dhaka'

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

# Accurate CPU usage (using top for more reliable results)
CPU_USAGE=$(top -bn1 | grep "Cpu(s)" | awk '{print $2 + $4}' | awk '{printf "%.1f%%", $1}')

# Alternative CPU usage calculation in case the above doesn't work
if [[ -z "$CPU_USAGE" || "$CPU_USAGE" == "0.0%" ]]; then
  # Fallback to /proc/stat method with longer sampling for more accuracy
  cpu_idle_1=$(awk '/^cpu / {print $5}' /proc/stat)
  cpu_total_1=$(awk '/^cpu / {print $2+$3+$4+$5+$6+$7+$8}' /proc/stat)
  sleep 2  # Longer sampling period for better accuracy
  cpu_idle_2=$(awk '/^cpu / {print $5}' /proc/stat)
  cpu_total_2=$(awk '/^cpu / {print $2+$3+$4+$5+$6+$7+$8}' /proc/stat)
  cpu_idle_diff=$((cpu_idle_2 - cpu_idle_1))
  cpu_total_diff=$((cpu_total_2 - cpu_total_1))
  if [ "$cpu_total_diff" -gt 0 ]; then
    # Calculate percentage without bc
    cpu_usage_raw=$((100 * (cpu_total_diff - cpu_idle_diff) / cpu_total_diff))
    CPU_USAGE="${cpu_usage_raw}%"
  else
    CPU_USAGE="0%"
  fi
fi

# Gather System Info
PUBLIC_IP=$($CURL -s https://ipv4.icanhazip.com)
USERS=$($WHO | $WC -l)
UPTIME_INFO=$($UPTIME -p)

# Improved Memory usage with percentage
MEM_TOTAL=$(free -m | awk '/Mem:/ {print $2}')
MEM_USED=$(free -m | awk '/Mem:/ {print $3}')
MEM_PERCENT=$(( MEM_USED * 100 / MEM_TOTAL ))
MEMORY="${MEM_USED}Mi used of ${MEM_TOTAL}Mi (${MEM_PERCENT}%)"

# Enhanced Disk usage with more detail
DISK_TOTAL=$(df -h / | awk 'NR==2 {print $2}')
DISK_USED=$(df -h / | awk 'NR==2 {print $3}')
DISK_PERCENT=$(df -h / | awk 'NR==2 {print $5}')
DISK="${DISK_PERCENT} (${DISK_USED} of ${DISK_TOTAL}) used on /"

# Detailed Load Average 
LOAD=$($UPTIME | $AWK -F'load average:' '{ print $2 }' | xargs)

# Enhanced Swap with percentage
SWAP_TOTAL=$(free -m | awk '/Swap:/ {print $2}')
if [ "$SWAP_TOTAL" -gt 0 ]; then
  SWAP_USED=$(free -m | awk '/Swap:/ {print $3}')
  SWAP_PERCENT=$(( SWAP_USED * 100 / SWAP_TOTAL ))
  SWAP="${SWAP_USED}Mi used of ${SWAP_TOTAL}Mi (${SWAP_PERCENT}%)"
else
  SWAP="0Mi used of 0Mi (0%)"
fi

KERNEL=$($UNAME -r)
ARCH=$($UNAME -m)

# Get Bangladesh time (UTC+6)
BDT_TIME=$(date '+%b %d, %Y - %I:%M %p (BDT UTC +6)')

# Build Telegram Message
MESSAGE=$(cat <<EOF
🔔 Server Status Report
$BDT_TIME

🖥️  Host: \`$HOSTNAME\`
🌐 Public IP: \`$PUBLIC_IP\`
👤 Logged-In Users: \`$USERS\`
🕒 Uptime: \`$UPTIME_INFO\`
🚀 CPU Usage: \`$CPU_USAGE\`
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
