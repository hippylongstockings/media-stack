"""Cloudflare tunnel status helper."""

from __future__ import annotations

import bot_settings as settings
from http_client import http_get_json


def tunnel_summary() -> str:
    if not all([settings.CF_API_BASE, settings.CF_API_TOKEN, settings.CF_ACCOUNT_ID, settings.CF_TUNNEL_ID]):
        return "*Tunnel*\nCloudflare API details not configured."

    url = f"{settings.CF_API_BASE}/accounts/{settings.CF_ACCOUNT_ID}/cfd_tunnel/{settings.CF_TUNNEL_ID}"
    headers = {"Authorization": f"Bearer {settings.CF_API_TOKEN}"}
    try:
        data = http_get_json(url, headers=headers)
    except Exception as exc:  # pragma: no cover
        return f"*Tunnel*\nAPI error: {exc}"

    result = data.get("result") or {}
    name = result.get("name", settings.CF_TUNNEL_ID)
    status = result.get("status", "unknown")
    healthy = result.get("connections", [])
    return "\n".join(
        [
            f"*Cloudflare Tunnel*\nName: {name}",
            f"Status: {status}",
            f"Connections: {len(healthy)}",
        ]
    )
