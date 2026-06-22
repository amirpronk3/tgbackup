#!/bin/bash

set -e

APP_DIR="/opt/tgbackup"
REPO="https://raw.githubusercontent.com/amirpronk3/tgbackup/main"

echo "🚀 TGBackup ZERO-FAIL Production Installer"

apt update -y
apt install -y python3 python3-pip cron curl

pip3 install --upgrade python-telegram-bot==20.7 requests

mkdir -p $APP_DIR/backups
mkdir -p $APP_DIR/logs

echo "Enter Bot Token:"
read -r TOKEN

# ---------- ENV SAFE ----------
cat > $APP_DIR/.env <<EOF
BOT_TOKEN=$TOKEN
ADMIN_ID=1057813886
EOF

# ---------- DOWNLOAD WITH VALIDATION ----------
echo "⬇️ Downloading bot..."

curl -fsSL "$REPO/bot.py" -o $APP_DIR/bot.py

# validate python before install
python3 -m py_compile $APP_DIR/bot.py

if [ $? -ne 0 ]; then
    echo "❌ Bot file invalid (syntax error). Install aborted."
    exit 1
fi

# ---------- SYSTEMD ----------
cat > /etc/systemd/system/tgbackup.service <<EOF
[Unit]
Description=TGBackup Production Agent
After=network-online.target
Wants=network-online.target

[Service]
Type=simple
WorkingDirectory=$APP_DIR
EnvironmentFile=$APP_DIR/.env
ExecStart=/usr/bin/python3 $APP_DIR/bot.py
Restart=always
RestartSec=3
StandardOutput=append:$APP_DIR/logs/out.log
StandardError=append:$APP_DIR/logs/error.log

[Install]
WantedBy=multi-user.target
EOF

systemctl daemon-reload
systemctl enable tgbackup
systemctl restart tgbackup

# ---------- CRON SAFE ----------
systemctl enable cron
systemctl restart cron

(crontab -l 2>/dev/null | grep -v "tgbackup autobackup" ; echo "0 */6 * * * cd $APP_DIR && /usr/bin/python3 bot.py autobackup >> logs/cron.log 2>&1") | crontab -

echo "✅ INSTALL COMPLETE (ZERO-FAIL MODE)"
echo "📦 Commands: /start /status /backup"
echo "⚡ Fully production ready"
