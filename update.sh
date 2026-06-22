cat >/root/update.sh <<'EOF'
#!/bin/bash

set -e

BOT="/opt/tgbackup/bot.py"

cp "$BOT" "$BOT.bak.$(date +%s)"

python3 - <<'PY'
from pathlib import Path

p = Path("/opt/tgbackup/bot.py")
txt = p.read_text()

if "AUTOBACKUP_MODE" not in txt:

    inject = '''

# ===== AUTOBACKUP_MODE =====
import sys
import asyncio

async def cron_backup():
    app = ApplicationBuilder().token(BOT_TOKEN).build()
    file = create_backup()

    with open(file, "rb") as f:
        await app.bot.send_document(
            chat_id=ADMIN_ID,
            document=f
        )

if __name__ == "__main__":
    if len(sys.argv) > 1 and sys.argv[1] == "autobackup":
        asyncio.run(cron_backup())
        sys.exit(0)
'''

    txt = txt.replace(
        'if __name__ == "__main__":\n    main()',
        inject + '\n\nif __name__ == "__main__":\n    main()'
    )

    p.write_text(txt)

PY

(crontab -l 2>/dev/null | grep -v "bot.py autobackup" ; echo "0 */6 * * * /usr/bin/python3 /opt/tgbackup/bot.py autobackup >/dev/null 2>&1") | crontab -

systemctl restart tgbackup

echo "OK - cron backup installed"
crontab -l
EOF

chmod +x /root/update.sh
bash /root/update.sh