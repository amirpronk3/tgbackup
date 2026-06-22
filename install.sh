#!/bin/bash

set -e

echo "📦 Telegram Backup Bot Installer"

INSTALL_DIR="/opt/tgbackup"
BOT_FILE="$INSTALL_DIR/bot.py"
SERVICE_FILE="/etc/systemd/system/tgbackup.service"

# ---------- CHECK INSTALL ----------

if [ -f "$BOT_FILE" ]; then
MODE="update"
echo "♻️ Existing installation detected -> UPDATE MODE"
else
MODE="install"
echo "🆕 Fresh install mode"
fi

apt update -y
apt install -y python3 python3-pip cron

pip3 install --upgrade python-telegram-bot==20.7

mkdir -p "$INSTALL_DIR/backups"

echo "Enter Bot Token:"
read -r TOKEN

# ---------- WRITE BOT ----------

cat > "$BOT_FILE" <<EOF
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
RETENTION = 5

os.makedirs(BACKUP_DIR, exist_ok=True)

def cleanup():
files = sorted(
[os.path.join(BACKUP_DIR, f) for f in os.listdir(BACKUP_DIR)],
key=os.path.getctime
)
while len(files) > RETENTION:
try:
os.remove(files[0])
files.pop(0)
except:
break

def create_backup():
now = datetime.now().strftime("%Y-%m-%d_%H-%M-%S")
path = f"{BACKUP_DIR}/backup_{now}.tar.gz"

```
with tarfile.open(path, "w:gz") as tar:
    for p in BACKUP_PATHS:
        if os.path.exists(p):
            tar.add(p)

cleanup()
return path
```

async def send_backup(app, chat_id):
file = create_backup()
with open(file, "rb") as f:
await app.bot.send_document(chat_id=chat_id, document=f)

START_TEXT = """
🤖 Backup Bot Active

/start
/status
/backup
"""

async def start(update: Update, context: ContextTypes.DEFAULT_TYPE):
if update.effective_user.id != ADMIN_ID:
return
await update.message.reply_text(START_TEXT)

async def status(update: Update, context: ContextTypes.DEFAULT_TYPE):
if update.effective_user.id != ADMIN_ID:
return
await update.message.reply_text("🟢 Running")

async def backup(update: Update, context: ContextTypes.DEFAULT_TYPE):
if update.effective_user.id != ADMIN_ID:
return
await update.message.reply_text("⏳ Backup...")
await send_backup(context.application, update.effective_chat.id)
await update.message.reply_text("✅ Done")

async def cron_backup():
app = ApplicationBuilder().token(BOT_TOKEN).build()
await send_backup(app, ADMIN_ID)

def run():
app = ApplicationBuilder().token(BOT_TOKEN).build()

```
app.add_handler(CommandHandler("start", start))
app.add_handler(CommandHandler("status", status))
app.add_handler(CommandHandler("backup", backup))

app.run_polling(drop_pending_updates=True)
```

if **name** == "**main**":

```
if len(sys.argv) > 1 and sys.argv[1] == "autobackup":
    asyncio.run(cron_backup())
    sys.exit(0)

run()
```

EOF

# ---------- SYSTEMD ----------

cat > "$SERVICE_FILE" <<EOF
[Unit]
Description=Telegram Backup Bot
After=network-online.target
Wants=network-online.target

[Service]
Type=simple
WorkingDirectory=$INSTALL_DIR

ExecStart=/usr/bin/python3 $BOT_FILE

Restart=always
RestartSec=5

[Install]
WantedBy=multi-user.target
EOF

systemctl daemon-reload
systemctl enable tgbackup
systemctl restart tgbackup

# ---------- CRON ----------

systemctl enable cron
systemctl restart cron

(crontab -l 2>/dev/null | grep -v "bot.py autobackup" ; echo "0 */6 * * * /usr/bin/python3 $BOT_FILE autobackup >/dev/null 2>&1") | crontab -

# ---------- RESULT ----------

if [ "$MODE" = "install" ]; then
echo "✅ Fresh installation completed"
else
echo "♻️ Update completed successfully"
fi

echo "🤖 Commands: /start /status /backup"
echo "⏰ Auto backup: every 6 hours"