"""Command dispatch and handlers for incoming Telegram bot commands."""

from __future__ import annotations
from bot_settings import DISK_MOUNT_PATH
from services import disk as disk_service
from services import docker as docker_service
from services import transmission as transmission_service
from services import tunnel as tunnel_service
from telegram_client import send_message


def handle_command(command: str) -> None:
    cmd = command.strip().lower()
    if cmd in ("/start", "/help"):
        help_lines = [
            "*Media Stack Bot*",
            "Commands:",
            "`/help` – this message",
            "`/ping` – connectivity check",
            "`/services` – docker compose service states",
            "`/transmission` – torrent stats",
            f"`/disk` – `{DISK_MOUNT_PATH}` usage",
            "`/tunnel` – Cloudflare tunnel status",
        ]
        send_message("\n".join(help_lines), parse_mode="Markdown")
    elif cmd == "/ping":
        send_message("Pong ✅")
    elif cmd == "/transmission":
        try:
            send_message(transmission_service.transmission_summary(), parse_mode="Markdown")
        except Exception as exc:  # pragma: no cover
            send_message(f"Transmission query failed: {exc}")
    elif cmd == "/services":
        send_message(docker_service.services_summary(), parse_mode="Markdown")
    elif cmd == "/disk":
        send_message(disk_service.disk_summary(), parse_mode="Markdown")
    elif cmd == "/tunnel":
        send_message(tunnel_service.tunnel_summary(), parse_mode="Markdown")
    else:
        send_message("Unknown command. Try /help.")
