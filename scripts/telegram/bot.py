"""Main entry point for the Telegram media stack bot."""

from __future__ import annotations

import time

import bot_settings as settings
from alerts import check_alerts, init_alert_state
from commands import handle_command
from telegram_client import send_message, send_message_to, telegram_get


def main() -> None:
    last_update_id: int | None = None
    init_alert_state()
    send_message("Telegram bot online ✅")
    while True:
        try:
            params = {"timeout": settings.POLL_TIMEOUT}
            if last_update_id is not None:
                params["offset"] = last_update_id + 1
            data = telegram_get("getUpdates", params)
            for update in data.get("result", []):
                last_update_id = update["update_id"]
                message = update.get("message") or update.get("channel_post")
                if not message:
                    continue
                chat_id = str(message["chat"]["id"])
                if chat_id not in settings.AUTHORIZED_CHAT_IDS:
                    send_message_to(chat_id, "Access denied. This bot is restricted.")
                    continue
                text = message.get("text")
                if not text:
                    continue
                handle_command(text)
            check_alerts()
        except Exception as exc:  # pragma: no cover
            print(f"[telegram-bot] error: {exc}")
            time.sleep(5)


if __name__ == "__main__":
    try:
        main()
    except KeyboardInterrupt:
        send_message("Telegram bot shutting down ❌")
