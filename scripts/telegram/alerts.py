"""Alerting routines for disk capacity monitoring."""

from __future__ import annotations

import shutil

import bot_settings as settings
from telegram_client import send_message

ALERT_STATE = {
    "disk_low": False,
}


def check_alerts() -> None:
    check_disk_alert()


def check_disk_alert() -> None:
    try:
        usage = shutil.disk_usage(settings.DISK_MOUNT_PATH)
    except FileNotFoundError:
        return

    free_gb = usage.free / 1_073_741_824
    if free_gb < settings.DISK_WARN_THRESHOLD and not ALERT_STATE["disk_low"]:
        send_message(
            "\n".join(
                [
                    "*Disk Alert*",
                    f"Path: {settings.DISK_MOUNT_PATH}",
                    f"Free space: {free_gb:.1f} GiB",
                ]
            ),
            parse_mode="Markdown",
        )
        ALERT_STATE["disk_low"] = True
    elif free_gb > settings.DISK_WARN_THRESHOLD + 10 and ALERT_STATE["disk_low"]:
        send_message(
            "\n".join(
                [
                    "*Disk Recovered*",
                    f"Path: {settings.DISK_MOUNT_PATH}",
                    f"Free space: {free_gb:.1f} GiB",
                ]
            ),
            parse_mode="Markdown",
        )
        ALERT_STATE["disk_low"] = False


def init_alert_state() -> None:
    # Nothing to initialize currently; placeholder for future alert sources.
    return None
