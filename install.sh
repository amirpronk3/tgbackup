#!/bin/bash

set -e

APP_DIR="/opt/tgbackup"
REPO="https://raw.githubusercontent.com/amirpronk3/tgbackup/main"

echo "🚀 Installing TGBackup Enterprise..."

apt update -y
apt install -y python3 python3-pip cron curl

pip3 install --upgrade python-telegram-bot==20.7 requests

mkdir -p $APP_DIR/backups
mkdir -p $APP_DIR/logs

# ---------- TOKEN ----------

echo "Enter Bot Token:"
read -r TOKEN

echo "BOT_TOKEN=$TOKEN" > $APP_DIR/.env
echo "ADMIN_ID=1057813886" >> $APP_DIR/.env

# ---------- DOWNLOAD BOT ----------

curl -fsSL $REPO/bot.py -o $APP_DIR/bot.py

# ---------- SYSTEMD ----------

cat > /etc/systemd/system/tgbackup.service <<EOF
[Unit]
Description=TGBackup Enterprise Agent
After=network-online.target
Wants=network-online.target

[Service]
Type=simple
WorkingDirectory=$APP_DIR
EnvironmentFile=$APP_DIR/.env
ExecStart=/usr/bin/python3 $APP_DIR/bot.py
Restart=always
RestartSec=5
StandardOutput=append:$APP_DIR/logs/bot.log
StandardError=append:$APP_DIR/logs/error.log

[Install]
WantedBy=multi-user.target
EOF

systemctl daemon-reload
systemctl enable tgbackup
systemctl restart tgbackup

# ---------- CRON ----------

systemctl enable cron
systemctl restart cron

(crontab -l 2>/dev/null | grep -v "tgbackup autobackup" ; echo "0 */6 * * * /usr/bin/python3 $APP_DIR/bot.py autobackup >> $APP_DIR/logs/cron.log 2>&1") | crontab -

echo "✅ Enterprise installation completed"
echo "🤖 Commands: /start /status /backup"
echo "📦 Auto backup: every 6 hours"
echo "⚡ Systemd + Cron enabled"
