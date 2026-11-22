import array
import mmap
import os
import select
import socket
import struct
import time


class Client:
    def __init__(self, display):
        self.sock = socket.socket(socket.AF_UNIX)
        self.sock.connect(os.environ["XDG_RUNTIME_DIR"] + "/" + display)
        self.next = 2
        self.pending = bytearray()
        self.globals = {}
        self.xdgs = set()
        self.buffers = []
        self.registry = self.id()
        self.send(1, 1, self.u(self.registry))
        self.barrier()
        self.compositor = self.bind("wl_compositor", 4)
        self.subcompositor = self.bind("wl_subcompositor", 1)
        self.shm = self.bind("wl_shm", 1)
        self.viewporter = self.bind("wp_viewporter", 1)
        self.wm = self.bind("xdg_wm_base", 1)
        self.barrier()

    def id(self):
        v = self.next
        self.next += 1
        return v

    def u(self, *v):
        return struct.pack("<" + "I" * len(v), *v)

    def string(self, s):
        v = s.encode() + b"\0"
        return self.u(len(v)) + v.ljust((len(v) + 3) & ~3, b"\0")

    def send(self, obj, op, data=b"", fd=None):
        msg = self.u(obj, ((len(data) + 8) << 16) | op) + data
        if fd is None:
            self.sock.sendall(msg)
        else:
            self.sock.sendmsg(
                [msg], [(socket.SOL_SOCKET, socket.SCM_RIGHTS, array.array("i", [fd]))]
            )

    def bind(self, name, version):
        number, available = self.globals[name]
        obj = self.id()
        self.send(
            self.registry,
            0,
            self.u(number) + self.string(name) + self.u(min(version, available), obj),
        )
        return obj

    def read(self, timeout=0.1):
        if not select.select([self.sock], [], [], timeout)[0]:
            return
        chunk = self.sock.recv(65536)
        if not chunk:
            raise RuntimeError("Wayland disconnected")
        self.pending.extend(chunk)
        while len(self.pending) >= 8:
            obj, h = struct.unpack_from("<II", self.pending)
            size = h >> 16
            op = h & 65535
            if len(self.pending) < size:
                return
            body = bytes(self.pending[8:size])
            del self.pending[:size]
            if obj == 1 and op == 0:
                raise RuntimeError(repr(body))
            if obj == self.registry and op == 0:
                number, length = struct.unpack_from("<II", body)
                name = body[8 : 8 + length - 1].decode()
                version = struct.unpack_from("<I", body, 8 + ((length + 3) & ~3))[0]
                self.globals[name] = (number, version)
            if obj == getattr(self, "wm", None) and op == 0:
                self.send(obj, 3, body)
            if obj in self.xdgs and op == 0:
                self.send(obj, 4, body)
            if obj == getattr(self, "callback", None):
                self.done = True

    def barrier(self):
        self.callback = self.id()
        self.done = False
        self.send(1, 0, self.u(self.callback))
        end = time.monotonic() + 10
        while not self.done and time.monotonic() < end:
            self.read()
        if not self.done:
            raise RuntimeError("roundtrip timed out")

    def surface(self):
        s = self.id()
        self.send(self.compositor, 0, self.u(s))
        return s

    def buffer(self, width, height, pixel):
        fd = os.memfd_create("permission-test")
        os.ftruncate(fd, width * height * 4)
        mm = mmap.mmap(fd, width * height * 4)
        mm[:] = struct.pack("<I", pixel) * (width * height)
        self.buffers.append(mm)
        pool = self.id()
        self.send(self.shm, 0, self.u(pool, width * height * 4), fd)
        b = self.id()
        self.send(pool, 0, self.u(b, 0, width, height, width * 4, 0))
        self.send(pool, 1)
        os.close(fd)
        return b

    def paint(self, s, width, height, pixel):
        b = self.buffer(width, height, pixel)
        self.send(s, 1, self.u(b, 0, 0))
        self.send(s, 2, self.u(0, 0, width, height))
        self.send(s, 6)

    def window(self, app, title, width, height, pixel):
        s = self.surface()
        x = self.id()
        self.xdgs.add(x)
        self.send(self.wm, 2, self.u(x, s))
        t = self.id()
        self.send(x, 1, self.u(t))
        self.send(t, 2, self.string(title))
        self.send(t, 3, self.string(app))
        self.send(x, 3, self.u(0, 0, width, height))
        self.send(s, 6)
        self.barrier()
        self.paint(s, width, height, pixel)
        return s

    def layer(self, parent, width, height, x, y, pixel):
        s = self.surface()
        sub = self.id()
        self.send(self.subcompositor, 1, self.u(sub, s, parent))
        v = self.id()
        self.send(self.viewporter, 1, self.u(v, s))
        self.send(v, 2, self.u(width, height))
        self.send(sub, 1, struct.pack("<ii", x, y))
        self.paint(s, width, height, pixel)
        self.send(parent, 6)
        return s, sub, v


if __name__ == "__main__":
    native = Client(os.environ.get("WAYLAND_DISPLAY", "wayland-0"))
    native.window(
        "org.kernora.permission-test.native",
        "Native Linux control",
        260,
        220,
        0xFF3278D0,
    )
    android = Client("kernora-android-0")
    root = android.window(
        "waydroid.com.example.permissiontest", "Android permission regression", 1, 1, 0
    )
    android.layer(root, 360, 480, 0, 0, 0xFF248644)
    android.layer(root, 220, 120, 70, 180, 0xFFFFB52E)
    with open("/tmp/permission-client-ready", "w") as handle:
        handle.write("ready")
    while True:
        native.read(0.02)
        android.read(0.02)
