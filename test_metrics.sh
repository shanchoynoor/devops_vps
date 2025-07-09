#!/bin/bash

# This is a test script to verify system metrics collection

# Use Bangladesh time (UTC+6) for all timestamps in this script
export TZ='Asia/Dhaka'

echo "$(date '+%F %T') [INFO] Testing system metrics collection"

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
HOSTNAME=$(hostname)
PUBLIC_IP=$(curl -s https://ipv4.icanhazip.com || echo "N/A")
USERS=$(who | wc -l)
UPTIME_INFO=$(uptime -p)

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
LOAD=$(uptime | awk -F'load average:' '{ print $2 }' | xargs)

# Enhanced Swap with percentage
SWAP_TOTAL=$(free -m | awk '/Swap:/ {print $2}')
if [ "$SWAP_TOTAL" -gt 0 ]; then
  SWAP_USED=$(free -m | awk '/Swap:/ {print $3}')
  SWAP_PERCENT=$(( SWAP_USED * 100 / SWAP_TOTAL ))
  SWAP="${SWAP_USED}Mi used of ${SWAP_TOTAL}Mi (${SWAP_PERCENT}%)"
else
  SWAP="0Mi used of 0Mi (0%)"
fi

KERNEL=$(uname -r)
ARCH=$(uname -m)

# Get Bangladesh time (UTC+6)
BDT_TIME=$(date '+%b %d, %Y - %I:%M %p (BDT UTC +6)')

# Print all metrics
echo "======= SYSTEM METRICS ======="
echo "Date and Time: $BDT_TIME"
echo "CPU Usage: $CPU_USAGE"
echo "Memory: $MEMORY"
echo "Disk: $DISK"
echo "Load Average: $LOAD"
echo "Swap: $SWAP"
echo "Host: $HOSTNAME"
echo "Public IP: $PUBLIC_IP"
echo "Users: $USERS"
echo "Uptime: $UPTIME_INFO"
echo "Architecture: $ARCH"
echo "Kernel: $KERNEL"
echo "============================"
