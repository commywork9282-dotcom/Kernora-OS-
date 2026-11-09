# SPDX-FileCopyrightText: 2026 Kernora Developers
# SPDX-License-Identifier: GPL-2.0-or-later

import os
import subprocess

TIMEOUT = 3
LIMIT = 1 << 20


def _environment() -> dict[str, str]:
    environment = dict(os.environ)
    environment["WAYLAND_DISPLAY"] = os.environ.get("KERNORA_HOST_WAYLAND_DISPLAY") or "wayland-0"
    return environment


def copy(data) -> None:
    if isinstance(data, bytes):
        data = data.decode("utf-8", "replace")
    text = str(data or "")[:LIMIT]
    if not text:
        return
    subprocess.run(["wl-copy", "--type", "text/plain;charset=utf-8", "--", text], env=_environment(),
                   stdin=subprocess.DEVNULL, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL,
                   timeout=TIMEOUT, check=False)


def paste(text: bool = True) -> str:
    try:
        result = subprocess.run(["wl-paste", "--no-newline", "--type", "text"], env=_environment(),
                                stdin=subprocess.DEVNULL, stdout=subprocess.PIPE, stderr=subprocess.DEVNULL,
                                timeout=TIMEOUT, check=False)
    except (OSError, subprocess.TimeoutExpired):
        return ""
    if result.returncode != 0:
        return ""
    return result.stdout[:LIMIT].decode("utf-8", "replace")
