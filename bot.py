import os
import sys
import tarfile
import asyncio
from datetime import datetime
from telegram import Update
from telegram.ext import ApplicationBuilder, CommandHandler, ContextTypes

# ---------- SAFE CONFIG ----------
BOT_TOKEN = os.getenv("BOT_TOKEN")
ADMIN_ID = int(os.getenv("ADMIN_ID", "0"))

BACKUP_DIR = "/opt/tgbackup/backups"
RETENTION = 5

BACKUP_PATHS = [
    "/root",
    "/etc/x-ui",
    "/var/lib/marzban",
    "/opt/marzban"
]

os.makedirs(BACKUP_DIR, exist_ok=True)

# ---------- CORE SAFE BACKUP ----------
def create_backup():
    now = datetime.now().strftime("%Y-%m-%d_%H-%M-%S")
    file_path = f"{BACKUP_DIR}/backup_{now}.tar.gz"

    with tarfile.open(file_path, "w:gz") as tar:
        for p in BACKUP_PATHS:
            if os.path.exists(p):
                tar.add(p)

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

    return file_path


async def send_backup(app, chat_id):
    file = create_backup()
    with open(file, "rb") as f:
        await app.bot.send_document(chat_id=chat_id, document=f)


# ---------- COMMANDS ----------
START_TEXT = """
🤖 TGBackup Production

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
    await update.message.reply_text("🟢 Online")


async def backup(update: Update, context: ContextTypes.DEFAULT_TYPE):
    if update.effective_user.id != ADMIN_ID:
        return
    await update.message.reply_text("⏳ Backup...")
    await send_backup(context.application, update.effective_chat.id)
    await update.message.reply_text("✅ Done")


# ---------- CRON MODE ----------
async def cron():
    app = ApplicationBuilder().token(BOT_TOKEN).build()
    await send_backup(app, ADMIN_ID)


# ---------- ENTRY ----------
def main():
    app = ApplicationBuilder().token(BOT_TOKEN).build()

    app.add_handler(CommandHandler("start", start))
    app.add_handler(CommandHandler("status", status))
    app.add_handler(CommandHandler("backup", backup))

    app.run_polling(drop_pending_updates=True)


if __name__ == "__main__":
    if len(sys.argv) > 1 and sys.argv[1] == "autobackup":
        asyncio.run(cron())
        sys.exit(0)

    main()
