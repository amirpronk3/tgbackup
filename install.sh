#!/bin/bash

set -e

echo "📦 Installing Telegram Backup Bot..."

apt update -y
apt install -y python3 python3-pip cron

pip3 install --upgrade python-telegram-bot==20.7

mkdir -p /opt/tgbackup/backups

echo "Enter Bot Token:"
read -r TOKEN

cat > /opt/tgbackup/bot.py <<EOF
import os
import sys
import tarfile
import asyncio
from datetime import datetime
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
RETENTION_COUNT = 5

os.makedirs(BACKUP_DIR, exist_ok=True)

def cleanup_old_backups():
files = sorted(
[os.path.join(BACKUP_DIR, f) for f in os.listdir(BACKUP_DIR)],
key=os.path.getctime
)

```
while len(files) > RETENTION_COUNT:
    try:
        os.remove(files[0])
        files.pop(0)
    except:
        break
```

def create_backup():
now = datetime.now().strftime("%Y-%m-%d_%H-%M-%S")
filename = f"{BACKUP_DIR}/backup_{now}.tar.gz"

```
with tarfile.open(filename, "w:gz") as tar:
    for path in BACKUP_PATHS:
        if os.path.exists(path):
            tar.add(path)

cleanup_old_backups()
return filename
```

async def send_backup(app, chat_id):
backup_file = create_backup()

```
with open(backup_file, "rb") as f:
    await app.bot.send_document(
        chat_id=chat_id,
        document=f
    )
```

async def backup_cmd(update: Update, context: ContextTypes.DEFAULT_TYPE):
if update.effective_user.id != ADMIN_ID:
return

```
await update.message.reply_text("⏳ Creating backup...")
await send_backup(context.application, update.effective_chat.id)
await update.message.reply_text("✅ Backup sent")
```

async def status_cmd(update: Update, context: ContextTypes.DEFAULT_TYPE):
if update.effective_user.id != ADMIN_ID:
return

```
await update.message.reply_text("🟢 Bot Online")
```

async def cron_backup():
app = ApplicationBuilder().token(BOT_TOKEN).build()
await send_backup(app, ADMIN_ID)

def run_bot():
app = ApplicationBuilder().token(BOT_TOKEN).build()

```
app.add_handler(CommandHandler("backup", backup_cmd))
app.add_handler(CommandHandler("status", status_cmd))

app.run_polling(drop_pending_updates=True)
```

if **name** == "**main**":

```
if len(sys.argv) > 1 and sys.argv[1] == "autobackup":
    asyncio.run(cron_backup())
    sys.exit(0)

run_bot()
```

EOF

cat > /etc/systemd/system/tgbackup.service <<EOF
[Unit]
Description=Telegram Backup Bot
After=network.target

[Service]
Type=simple
WorkingDirectory=/opt/tgbackup
ExecStart=/usr/bin/python3 /opt/tgbackup/bot.py
Restart=always
RestartSec=5

[Install]
WantedBy=multi-user.target
EOF

systemctl daemon-reload
systemctl enable tgbackup
systemctl restart tgbackup

systemctl enable cron
systemctl restart cron

(crontab -l 2>/dev/null | grep -v "bot.py autobackup" ; echo "0 */6 * * * /usr/bin/python3 /opt/tgbackup/bot.py autobackup >/dev/null 2>&1") | crontab -

echo "✅ Installation completed"
echo "🤖 Commands:"
echo "/backup"
echo "/status"

echo "⏰ Auto backup: every 6 hours"
EOF

chmod +x install.sh
