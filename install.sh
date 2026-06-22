#!/bin/bash

set -e

APP_DIR="/opt/tgbackup"
BOT_FILE="$APP_DIR/bot.py"
REPO="https://raw.githubusercontent.com/amirpronk3/tgbackup/main"

echo "♻️ Updating Telegram Backup Bot..."

apt install -y curl

curl -fsSL "$REPO/bot.py" -o "$BOT_FILE"

systemctl restart tgbackup

echo "✅ Update completed"
