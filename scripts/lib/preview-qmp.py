#!/usr/bin/env python3
"""usage: preview-qmp.py SOCKET COMMAND [ARGS]

  shot FILE.png              screendump
  move X Y                   move the pointer
  click X Y [left|right]     click at a point
  drag X1 Y1 X2 Y2 [MS]      press, move in steps over MS milliseconds, release
  hold X1 Y1 X2 Y2 [MS]      like drag, but leaves the button down
  release                    release the left button
  scroll X Y NOTCHES         wheel notches, positive is up
  key QCODE...               press a key combination, e.g. key meta_l a
  type TEXT                  type ASCII text
  quit                       power off
  run COMMAND                (with the serial socket) run a root shell command

Coordinates are screen pixels of the preview display (1440x900); the USB
tablet reports absolute positions, so they land exactly where asked.
"""

from __future__ import annotations

import json
import socket
import sys
import time

WIDTH, HEIGHT = 1440, 900
ABS_MAX = 0x7FFF


class Qmp:
    def __init__(self, path: str) -> None:
        self.sock = socket.socket(socket.AF_UNIX, socket.SOCK_STREAM)
        self.sock.connect(path)
        self.stream = self.sock.makefile("rwb", buffering=0)
        json.loads(self.stream.readline())
        self.command("qmp_capabilities")

    def command(self, name: str, arguments: dict | None = None):
        message = {"execute": name}
        if arguments is not None:
            message["arguments"] = arguments
        self.stream.write(json.dumps(message).encode() + b"\n")
        while True:
            reply = json.loads(self.stream.readline())
            if "error" in reply:
                raise RuntimeError(reply["error"])
            if "return" in reply:
                return reply["return"]

    def events(self, events: list[dict]) -> None:
        self.command("input-send-event", {"events": events})

    def move(self, x: float, y: float) -> None:
        ax = round(max(0, min(WIDTH - 1, x)) * ABS_MAX / (WIDTH - 1))
        ay = round(max(0, min(HEIGHT - 1, y)) * ABS_MAX / (HEIGHT - 1))
        self.events([
            {"type": "abs", "data": {"axis": "x", "value": ax}},
            {"type": "abs", "data": {"axis": "y", "value": ay}},
        ])

    def button(self, down: bool, button: str = "left") -> None:
        self.events([{"type": "btn", "data": {"down": down, "button": button}}])


def glide(qmp: Qmp, x1, y1, x2, y2, duration_ms: int) -> None:
    steps = max(2, duration_ms // 8)
    for i in range(1, steps + 1):
        t = i / steps
        eased = 1 - (1 - t) ** 2
        qmp.move(x1 + (x2 - x1) * eased, y1 + (y2 - y1) * eased)
        time.sleep(duration_ms / 1000 / steps)


KEYS = {" ": "spc", ".": "dot", "-": "minus", "/": "slash", ",": "comma",
        "=": "equal", ";": "semicolon", "'": "apostrophe", "\\": "backslash",
        "[": "bracket_left", "]": "bracket_right", "`": "grave_accent"}
SHIFTED = {"|": "backslash", ">": "dot", "<": "comma", '"': "apostrophe",
           ":": "semicolon", "_": "minus", "?": "slash", "*": "8", "&": "7",
           "$": "4", "!": "1", "@": "2", "#": "3", "%": "5", "^": "6",
           "(": "9", ")": "0", "+": "equal", "{": "bracket_left",
           "}": "bracket_right", "~": "grave_accent"}


def run_on_console(path: str, command: str, timeout: float = 60) -> int:
    import re

    marker = f"__KERNORA_DONE_{int(time.time() * 1000)}__"
    done = re.compile(re.escape(marker) + r"(\d+)")
    sock = socket.socket(socket.AF_UNIX, socket.SOCK_STREAM)
    sock.connect(path)
    sock.settimeout(0.3)

    def drain(seconds: float) -> bytes:
        data = b""
        end = time.time() + seconds
        while time.time() < end:
            try:
                chunk = sock.recv(65536)
            except socket.timeout:
                continue
            if not chunk:
                break
            data += chunk
        return data

    sock.sendall(b"\nstty -echo\n")
    drain(0.8)
    sock.settimeout(None)
    sock.sendall(f"{command}; echo {marker}$?\n".encode())
    sock.settimeout(0.3)
    buffer = b""
    deadline = time.time() + timeout
    while time.time() < deadline:
        buffer += drain(0.3)
        text = buffer.decode(errors="replace").replace("\r", "")
        match = done.search(text)
        if match:
            body = text[:match.start()]
            lines = [line for line in body.split("\n") if not line.rstrip().endswith("#")]
            print("\n".join(lines).strip("\n"))
            return int(match.group(1))
    print(buffer.decode(errors="replace"))
    print("timed out waiting for the command", file=sys.stderr)
    return 1


def push_archive(path: str, archive: str, destination: str) -> int:
    import base64

    data = base64.encodebytes(open(archive, "rb").read()).decode()
    script = (
        "cat > /tmp/kernora-push.b64 <<'KERNORA_PUSH'\n"
        + data
        + "KERNORA_PUSH\n"
        + f"base64 -d /tmp/kernora-push.b64 | tar -xzf - --no-same-owner -C {destination}"
        + " && rm /tmp/kernora-push.b64"
    )
    return run_on_console(path, script, timeout=1500)


def main(argv: list[str]) -> int:
    if len(argv) < 3:
        print(__doc__.strip(), file=sys.stderr)
        return 2
    if argv[2] == "run":
        return run_on_console(argv[1], argv[3])
    if argv[2] == "push":
        return push_archive(argv[1], argv[3], argv[4])
    qmp = Qmp(argv[1])
    command, args = argv[2], argv[3:]

    if command == "shot":
        qmp.command("screendump", {"filename": args[0], "format": "png"})
    elif command == "move":
        qmp.move(float(args[0]), float(args[1]))
    elif command == "click":
        qmp.move(float(args[0]), float(args[1]))
        time.sleep(0.05)
        button = args[2] if len(args) > 2 else "left"
        qmp.button(True, button)
        time.sleep(0.06)
        qmp.button(False, button)
    elif command in ("drag", "hold"):
        x1, y1, x2, y2 = (float(a) for a in args[:4])
        duration = int(args[4]) if len(args) > 4 else 300
        qmp.move(x1, y1)
        time.sleep(0.05)
        qmp.button(True)
        time.sleep(0.05)
        glide(qmp, x1, y1, x2, y2, duration)
        if command == "drag":
            qmp.button(False)
    elif command == "release":
        qmp.button(False)
    elif command == "scroll":
        qmp.move(float(args[0]), float(args[1]))
        notches = int(args[2])
        for _ in range(abs(notches)):
            button = "wheel-up" if notches > 0 else "wheel-down"
            qmp.button(True, button)
            qmp.button(False, button)
            time.sleep(0.05)
    elif command == "key":
        qmp.command("send-key", {
            "keys": [{"type": "qcode", "data": key} for key in args],
            "hold-time": 80,
        })
    elif command == "type":
        for char in " ".join(args):
            if char.isupper():
                keys = ["shift", char.lower()]
            elif char in SHIFTED:
                keys = ["shift", SHIFTED[char]]
            else:
                keys = [KEYS.get(char, char)]
            qmp.command("send-key", {
                "keys": [{"type": "qcode", "data": key} for key in keys],
                "hold-time": 40,
            })
            time.sleep(0.05)
    elif command == "quit":
        qmp.command("quit")
    else:
        print(__doc__.strip(), file=sys.stderr)
        return 2
    return 0


if __name__ == "__main__":
    raise SystemExit(main(sys.argv))
