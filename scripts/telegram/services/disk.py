"""Disk usage summary helper."""

from __future__ import annotations

import shutil

import bot_settings as settings


def disk_summary() -> str:
    try:
        usage = shutil.disk_usage(settings.DISK_MOUNT_PATH)
    except FileNotFoundError:
        return f"*Disk*\nPath {settings.DISK_MOUNT_PATH} not found."

    total = usage.total / 1_073_741_824
    used = usage.used / 1_073_741_824
    free = usage.free / 1_073_741_824
    warn = "⚠️" if free < settings.DISK_WARN_THRESHOLD else "✅"
    return "\n".join(
        [
            f"*Disk* ({settings.DISK_MOUNT_PATH})",
            f"Total: {total:.1f} GiB",
            f"Used: {used:.1f} GiB",
            f"Free: {free:.1f} GiB {warn}",
        ]
    )
