# Server Status Monitor

A Bash script that monitors VPS/server status and sends reports via Telegram and email.

## Overview

This tool periodically checks your server's vital statistics and sends a formatted report to both a Telegram chat and an email address. All timestamps are in Bangladesh Time (UTC+6).

## Features

- 📊 **Comprehensive System Monitoring**:
  - CPU usage (measured with 1-second sampling)
  - Memory usage
  - Disk space
  - Swap usage
  - System load
  - Uptime
  - Logged-in users
  - System information (kernel, architecture)
  - Public IP address

- 📱 **Telegram Integration**: Sends beautifully formatted messages with Markdown support
- 📧 **Email Notifications**: Delivers the same status report via email
- 🌍 **Timezone Aware**: All timestamps use Bangladesh Time (UTC+6)
- 📝 **Detailed Logging**: Maintains logs for troubleshooting

## Installation

1. Clone the repository:
   ```bash
   git clone https://github.com/yourusername/Get_VPS_Server_Status.git
   cd Get_VPS_Server_Status
   ```

2. Create a `.env` file with your configuration:
   ```bash
   cp .env.example .env
   nano .env
   ```

3. Make the script executable:
   ```bash
   chmod +x server_status.sh
   ```

## Configuration

Create a `.env` file in the same directory as the script with the following content:

```
# Telegram Bot Configuration
TELEGRAM_BOT_TOKEN="your_telegram_bot_token"
TELEGRAM_CHAT_ID="your_telegram_chat_id"

# Email Configuration
EMAIL_FROM="server@example.com"
EMAIL_TO="admin@example.com"
```

### Telegram Bot Setup

1. Create a new bot using [@BotFather](https://t.me/BotFather) on Telegram
2. Get your bot token
3. Start a chat with your bot and get your chat ID (you can use [@RawDataBot](https://t.me/RawDataBot))

### Email Setup

The script uses `msmtp` to send emails. Make sure it's properly configured on your system.

## Usage

### Manual Execution

```bash
./server_status.sh
```

### Scheduled Execution (Recommended)

Add to crontab to run periodically:

```bash
# Run every hour
0 * * * * /path/to/Get_VPS_Server_Status/server_status.sh

# Run twice a day (8 AM and 8 PM BDT)
0 2,14 * * * /path/to/Get_VPS_Server_Status/server_status.sh
```

Note: Cron runs in the server's local timezone. If your server is not in Bangladesh (UTC+6), adjust the times accordingly.

## Sample Output

```
🔔 Server Status Report
Jul 09, 2025 - 05:09 PM (BDT UTC +6)

🖥️  Host: `your-server`
🌐 Public IP: `123.45.67.89`
👤 Logged-In Users: `2`
🕒 Uptime: `up 15 days, 7 hours, 23 minutes`
🚀 CPU Usage: `12%`
🧠 Memory: `1.2Gi used of 4.0Gi`
💾 Disk: `43% used on /`
📈 Load Avg: `0.15, 0.10, 0.05`
🔃 Swap: `0B used of 2.0Gi`
⚙️  Arch: `x86_64`
🔧 Kernel: `5.15.0-76-generic`
```

## Dependencies

The script requires the following command-line tools:
- curl
- who
- wc
- uptime
- awk
- free
- df
- uname
- msmtp (for email functionality)

## Logs

Logs are stored in the `logs` directory in the same folder as the script.

## Troubleshooting

- Check the log file at `logs/system_status.log` for errors
- Ensure all dependencies are installed
- Verify your Telegram bot token and chat ID are correct
- Confirm your email configuration is working

## License

This project is licensed under the MIT License - see the LICENSE file for details.

## Contributing

Contributions are welcome! Please feel free to submit a Pull Request.

1. Fork the repository
2. Create your feature branch (`git checkout -b feature/amazing-feature`)
3. Commit your changes (`git commit -m 'Add some amazing feature'`)
4. Push to the branch (`git push origin feature/amazing-feature`)
5. Open a Pull Request
