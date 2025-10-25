# Telegram Bot

This bot polls Telegram for messages in the authorised chat and can answer several useful commands:

- `/help` – list available commands.
- `/ping` – connectivity check.
- `/services` – show `docker compose` service status (up/down).
- `/transmission` – torrent counts, bandwidth, and titles in progress/completed.
- `/disk` – usage summary for `DISK_MOUNT_PATH` (warns below threshold).
- `/tunnel` – Cloudflare tunnel status (requires API credentials).

It uses the native Telegram HTTP API (no third-party libraries) and talks directly to Transmission’s RPC endpoint.

## Environment variables

Set these in `.env` (values are already referenced in `docker-compose.yml`):

```env
TGRAM_BOT_TOKEN=123456:ABCDEF        # from @BotFather
TGRAM_CHAT_ID=987654321              # your personal or group chat ID
```

Optional overrides:

```env
TRANSMISSION_RPC_URL=http://vpn:9091/transmission/rpc
TGRAM_POLL_TIMEOUT=60
SERVICES_TO_CHECK=traefik,vpn,transmission,lidarr,prowlarr
DISK_MOUNT_PATH=/opt/media
DISK_WARN_THRESHOLD_GB=50
CF_API_BASE=https://api.cloudflare.com/client/v4
CF_API_TOKEN=REPLACE
CF_ACCOUNT_ID=REPLACE
CF_TUNNEL_ID=REPLACE
```

## Usage

1. Make sure the token and chat ID are populated in `.env`.
2. Start the service alongside the rest of the stack:
   ```bash
   docker compose up -d telegram-bot
   ```
3. Message the bot in Telegram (`/start`) to see the help text.

Because the bot is tied to a single chat ID, it ignores commands from other chats/users. Extend `scripts/telegram/bot.py` if you want more features (e.g., querying other services or sending proactive alerts). The script intentionally uses standard library modules so it is easy to maintain without additional dependencies. Add cron jobs or scripts that call `send_message()` to push proactive alerts (e.g., failed imports, low disk space).

## Alerts

The bot automatically checks for:

- Low disk space on `DISK_MOUNT_PATH` (warns below `DISK_WARN_THRESHOLD_GB`, clears once it rises 10 GiB above).

Extend `check_alerts()` to add more hooks (e.g., VPN down, tunnel offline). You can also call `send_message()` from other scripts/cron jobs for custom notifications.
