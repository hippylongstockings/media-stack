"""Environment-driven configuration values for the Telegram bot."""

from __future__ import annotations

import os
import ssl


BOT_TOKEN = os.environ["TGRAM_BOT_TOKEN"]
PRIMARY_CHAT_ID = str(os.environ["TGRAM_CHAT_ID"])
AUTHORIZED_CHAT_IDS = {
    chat.strip()
    for chat in os.environ.get("TGRAM_ALLOWED_CHAT_IDS", PRIMARY_CHAT_ID).split(",")
    if chat.strip()
}

_tg_base = os.environ.get("TELEGRAM_API_BASE")
if _tg_base:
    if "{token}" in _tg_base:
        TELEGRAM_API_BASE = _tg_base.format(token=BOT_TOKEN)
    else:
        base = _tg_base.rstrip("/")
        if base.endswith(BOT_TOKEN):
            TELEGRAM_API_BASE = base
        elif base.endswith("bot"):
            TELEGRAM_API_BASE = f"{base}{BOT_TOKEN}"
        else:
            TELEGRAM_API_BASE = f"{base}/{BOT_TOKEN}"
else:
    TELEGRAM_API_BASE = f"https://api.telegram.org/bot{BOT_TOKEN}"

SSL_CONTEXT = ssl._create_unverified_context()

TRANSMISSION_RPC_URL = os.environ.get("TRANSMISSION_RPC_URL", "http://vpn:9091/transmission/rpc")
CF_API_BASE = os.environ.get("CF_API_BASE")
CF_API_TOKEN = os.environ.get("CF_API_TOKEN")
CF_ACCOUNT_ID = os.environ.get("CF_ACCOUNT_ID")
CF_TUNNEL_ID = os.environ.get("CF_TUNNEL_ID")
SERVICES_TO_CHECK = os.environ.get(
    "SERVICES_TO_CHECK",
    "traefik,vpn,transmission,lidarr,prowlarr",
).split(",")
DISK_MOUNT_PATH = os.environ.get("DISK_MOUNT_PATH") or os.environ.get("DATADIR", "/opt/media")
DISK_WARN_THRESHOLD = int(os.environ.get("DISK_WARN_THRESHOLD_GB", "50"))
DOCKER_API_URL = os.environ.get("DOCKER_API_URL", "http://socket-proxy:2375")
POLL_TIMEOUT = int(os.environ.get("TGRAM_POLL_TIMEOUT", "60"))
