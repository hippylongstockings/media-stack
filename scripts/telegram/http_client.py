"""HTTP utilities used across service integrations."""

from __future__ import annotations

import json
import urllib.request


def http_get_json(url: str, headers: dict | None = None, timeout: int = 10) -> dict:
    """Fetch JSON payload from an HTTP endpoint."""
    req = urllib.request.Request(url, headers=headers or {})
    with urllib.request.urlopen(req, timeout=timeout) as resp:
        return json.load(resp)

