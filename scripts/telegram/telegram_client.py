"""Lightweight Telegram client helpers for interacting with the Bot API."""

from __future__ import annotations

import json
import urllib.parse
import urllib.request

import bot_settings as settings


def telegram_get(method: str, params: dict | None = None) -> dict:
    query = ""
    if params:
        query = "?" + urllib.parse.urlencode(params)
    with urllib.request.urlopen(
        f"{settings.TELEGRAM_API_BASE}/{method}{query}",
        context=settings.SSL_CONTEXT,
    ) as resp:
        return json.load(resp)


def telegram_post(method: str, payload: dict) -> dict:
    data = json.dumps(payload).encode("utf-8")
    req = urllib.request.Request(
        f"{settings.TELEGRAM_API_BASE}/{method}",
        data=data,
        headers={"Content-Type": "application/json"},
        method="POST",
    )
    with urllib.request.urlopen(req, context=settings.SSL_CONTEXT) as resp:
        return json.load(resp)


def send_message(text: str, parse_mode: str | None = None) -> None:
    payload = {"chat_id": settings.PRIMARY_CHAT_ID, "text": text}
    if parse_mode:
        payload["parse_mode"] = parse_mode
    try:
        telegram_post("sendMessage", payload)
    except Exception as exc:  # pragma: no cover - best effort logging
        print(f"[telegram-bot] failed to send message: {exc}")


def send_message_to(chat_id: str, text: str) -> None:
    payload = {"chat_id": chat_id, "text": text}
    try:
        telegram_post("sendMessage", payload)
    except Exception as exc:  # pragma: no cover
        print(f"[telegram-bot] failed to reply to unauthorized chat {chat_id}: {exc}")
