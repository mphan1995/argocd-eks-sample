from __future__ import annotations

import socket
from typing import Any, Dict


def port_open(host: str, port: int) -> bool:
    try:
        with socket.create_connection((host, port), timeout=1):
            return True
    except OSError:
        return False


def stack_status() -> Dict[str, Any]:
    return {
        "gitea": {"port": 3000, "ok": port_open("127.0.0.1", 3000)},
        "jenkins": {"port": 8080, "ok": port_open("127.0.0.1", 8080)},
        "registry": {"port": 5000, "ok": port_open("127.0.0.1", 5000)},
        "nexus": {"port": 8081, "ok": port_open("127.0.0.1", 8081)},
    }
