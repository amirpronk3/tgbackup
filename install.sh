#!/bin/bash

set -e

REPO="https://raw.githubusercontent.com/amirpronk3/tgbackup/main"
APP_DIR="/opt/tgbackup"
BOT_FILE="$APP_DIR/bot.py"

echo "📦 Installing Telegram Backup Bot (PRODUCTION MODE)..."

# ---------- dependencies ----------

apt update -y
apt install -y python3 python3-pip cron curl

pip3 install --upgrade python-telegram-bot==20.7

# ---------- directories ----------

mkdir -p "$APP_DIR"
mkdir -p "$APP_DIR/backups"

# ---------- check install ----------

if [ -f "$BOT_FILE" ]; then
echo "♻️ Existing installation detected → UPDATE MODE"
else
echo "🆕 Fresh installation"
fi

# ---------- token ----------

echo "Enter Bot Token:"
read -r TOKEN

# ---------- download bot ----------

echo "⬇️ Downloading bot.py..."
curl -fsSL "$REPO/bot.py" -o "$BOT_FILE"

# ---------- inject token safely ----------

sed -i "s/**BOT_TOKEN**/$TOKEN/g" "$BOT_FILE"

# ---------- systemd ----------

cat > /etc/systemd/system/tgbackup.service <<EOF
[Unit]
Description=Telegram Backup Bot
After=network-online.target
Wants=network-online.target

[Service]
Type=simple
WorkingDirectory=$APP_DIR
ExecStart=/usr/bin/python3 $BOT_FILE
Restart=always
RestartSec=5

[Install]
WantedBy=multi-user.target
EOF

# ---------- enable service ----------

systemctl daemon-reload
systemctl enable tgbackup
systemctl restart tgbackup

# ---------- cron ----------

systemctl enable cron
systemctl restart cron

(crontab -l 2>/dev/null | grep -v "bot.py autobackup" ; echo "0 */6 * * * /usr/bin/python3 $BOT_FILE autobackup >/dev/null 2>&1") | crontab -

echo "✅ Installation completed (PRODUCTION READY)"
echo "🤖 Commands: /start /status /backup"
echo "⏰ Auto backup: every 6 hours"
