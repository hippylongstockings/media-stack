"""Docker/Compose service health summaries."""

from __future__ import annotations

import bot_settings as settings
from http_client import http_get_json


def compose_service_status(service: str) -> str:
    try:
        containers = http_get_json(f"{settings.DOCKER_API_URL}/containers/json")
    except Exception as exc:  # pragma: no cover
        return f"❓ error: {exc}"

    running = set()
    for container in containers:
        for name in container.get("Names", []):
            running.add(name.lstrip("/"))
    return "✅ running" if service in running else "⚠️ not running"


def services_summary() -> str:
    lines = ["*Service Status*"]
    for svc in filter(None, settings.SERVICES_TO_CHECK):
        status = compose_service_status(svc.strip())
        lines.append(f"`{svc}` — {status}")
    return "\n".join(lines)
