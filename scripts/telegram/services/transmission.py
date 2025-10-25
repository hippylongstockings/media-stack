"""Helpers for querying Transmission RPC for bot summaries."""

from __future__ import annotations

import json
import urllib.error
import urllib.request

import bot_settings as settings


def transmission_request(payload: dict) -> dict:
    data = json.dumps(payload).encode("utf-8")
    headers = {"Content-Type": "application/json"}
    request = urllib.request.Request(
        settings.TRANSMISSION_RPC_URL,
        data=data,
        headers=headers,
        method="POST",
    )
    try:
        with urllib.request.urlopen(request, timeout=10) as resp:
            return json.load(resp)
    except urllib.error.HTTPError as err:
        if err.code != 409:
            raise
        session_id = err.headers.get("X-Transmission-Session-Id")
        if not session_id:
            raise
        headers["X-Transmission-Session-Id"] = session_id
        request = urllib.request.Request(
            settings.TRANSMISSION_RPC_URL,
            data=data,
            headers=headers,
            method="POST",
        )
        with urllib.request.urlopen(request, timeout=10) as resp:
            return json.load(resp)


def transmission_summary() -> str:
    payload = {"method": "session-stats", "arguments": {}}
    stats = transmission_request(payload)["arguments"]
    torrents = transmission_request(
        {
            "method": "torrent-get",
            "arguments": {"fields": ["status", "name", "percentDone"]},
        }
    )["arguments"]["torrents"]

    statuses = {0: "stopped", 2: "checking", 4: "downloading", 6: "seeding"}
    counts = {"downloading": 0, "seeding": 0, "stopped": 0}
    in_progress: list[str] = []
    completed: list[str] = []

    for torrent in torrents:
        status = statuses.get(torrent["status"], "other")
        if status in counts:
            counts[status] += 1
        percent_done = torrent.get("percentDone", 0.0) * 100
        name = torrent.get("name", "Unnamed torrent")
        if status == "downloading":
            in_progress.append(f"- {name} ({percent_done:.1f}% done)")
        elif status == "seeding" or percent_done >= 99.9:
            state_label = "seeding" if status == "seeding" else "complete"
            completed.append(f"- {name} ({state_label})")

    lines = [
        "*Transmission Summary*",
        f"Active torrents: {stats.get('activeTorrentCount', 0)}",
        f"Seeding: {counts['seeding']}",
        f"Downloading: {counts['downloading']}",
        f"Stopped: {counts['stopped']}",
        f"Download speed: {stats.get('downloadSpeed', 0) / 1_048_576:.2f} MiB/s",
        f"Upload speed: {stats.get('uploadSpeed', 0) / 1_048_576:.2f} MiB/s",
    ]
    if in_progress:
        lines.append("")
        lines.append("*In Progress*")
        lines.extend(in_progress)
    if completed:
        lines.append("")
        lines.append("*Completed*")
        lines.extend(completed)
    if not in_progress and not completed:
        lines.append("")
        lines.append("No torrents in progress or recently completed.")
    return "\n".join(lines)
