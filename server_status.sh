#!/bin/bash

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

# Telegram Configuration
TOKEN="7987417305:AAGLsrd7IjsE2B9Cuo9P2rA7HLztiRdXaiM"
CHAT_ID="6192660854"

# Accurate CPU usage (1-second sampling)
cpu_idle_1=$(awk '/^cpu / {print $5}' /proc/stat)
cpu_total_1=$(awk '/^cpu / {print $2+$3+$4+$5+$6+$7+$8}' /proc/stat)
sleep 1
cpu_idle_2=$(awk '/^cpu / {print $5}' /proc/stat)
cpu_total_2=$(awk '/^cpu / {print $2+$3+$4+$5+$6+$7+$8}' /proc/stat)
cpu_idle_diff=$((cpu_idle_2 - cpu_idle_1))
cpu_total_diff=$((cpu_total_2 - cpu_total_1))
cpu_usage=$((100 * (cpu_total_diff - cpu_idle_diff) / cpu_total_diff))

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

# Escape Telegram MarkdownV2 special characters in a message
escape_markdown_v2() {
  sed -e 's/\\/\\\\/g' \
      -e 's/_/\\_/g' \
      -e 's/\*/\\*/g' \
      -e 's/\[/\\[/g' \
      -e 's/\]/\\]/g' \
      -e 's/(/\\(/g' \
      -e 's/)/\\)/g' \
      -e 's/[-.~>#\+=|{}!]/\\&/g'
}

# Build Telegram Message
MESSAGE=$(cat <<EOF
🔔 *Server Status Report*

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

# Send to Telegram with Markdown (NOT MarkdownV2)
$CURL -s -X POST "https://api.telegram.org/bot$TOKEN/sendMessage" \
  -d "chat_id=$CHAT_ID" \
  --data-urlencode "text=$MESSAGE" \
  -d "parse_mode=Markdown"

# Email configuration
EMAIL_TO="choyagency@gmail.com"
EMAIL_FROM="server@$HOSTNAME.local"
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
