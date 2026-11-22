import importlib.machinery
import importlib.util
import json
import socket
import struct
import sys
import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
SOURCE = (
    Path(sys.argv.pop(1))
    if len(sys.argv) > 1
    else ROOT / "packages/native/kernora-desktop/data/android/kernora-android-display"
)
loader = importlib.machinery.SourceFileLoader("display", str(SOURCE))
display = importlib.util.module_from_spec(
    importlib.util.spec_from_loader("display", loader)
)
loader.exec_module(display)
TABLE = json.loads(
    (
        ROOT / "packages/native/kernora-desktop/data/android/wayland-protocols.json"
    ).read_text()
)


class Permissions(unittest.TestCase):
    def setUp(self):
        self.sockets = [*socket.socketpair(), *socket.socketpair()]
        self.session = display.Session(
            TABLE, "/tmp", {}, set(), self.sockets[0], self.sockets[2]
        )
        self.session.tell_helper = lambda line: None
        for client, interface in (
            (2, "wl_compositor"),
            (3, "wp_viewporter"),
            (4, "xdg_wm_base"),
            (5, "wl_subcompositor"),
        ):
            self.session.client_object(client, interface)
        self.session.request(2, 0, self.u(10))
        self.session.request(4, 2, self.u(11, 10))
        self.root = self.session.surfaces[10]
        self.root.app = "com.example"
        self.root.mapped = True
        self.root.backing = self.session.inject("wl_surface")
        self.root.backing_sub = self.session.inject("wl_subsurface")
        self.root.backing_view = self.session.inject("wp_viewport")
        self.root.backing_rect = (0, 0, 360, 480)
        self.session.black = self.session.inject("wl_buffer")
        self.root.geometry = self.root.backing_rect
        self.background = self.layer(20, (360, 480), (0, 0))
        self.question = self.layer(30, (220, 120), (70, 180))
        self.apply()
        self.order = [
            self.root.backing,
            self.root.server_id,
            self.background.server_id,
            self.question.server_id,
        ]
        self.positions = {
            self.background.server_id: (0, 0),
            self.question.server_id: (70, 180),
        }
        self.session.server_out.clear()

    def tearDown(self):
        for item in self.sockets:
            item.close()

    @staticmethod
    def u(*values):
        return struct.pack("<" + "I" * len(values), *values)

    def layer(self, base, size, position):
        self.session.request(2, 0, self.u(base))
        self.session.request(3, 1, self.u(base + 1, base))
        self.session.request(5, 1, self.u(base + 2, base, 10))
        self.session.request(base + 1, 2, self.u(*size))
        self.session.request(base + 2, 1, struct.pack("<ii", *position))
        self.session.surfaces[base].has_buffer = True
        return self.session.surfaces[base]

    def apply(self):
        self.session.before_commit(self.root.server_id, self.root)

    def wire(self):
        data = bytes(self.session.server_out)
        self.session.server_out.clear()
        messages = []
        while data:
            target, header = struct.unpack_from("<II", data)
            size, opcode = header >> 16, header & 0xFFFF
            body, data = data[8:size], data[size:]
            messages.append((target, opcode, body))
            layer = next(
                (item for item in self.root.children if item.subsurface == target), None
            )
            surface = (
                layer.server_id
                if layer
                else self.root.backing
                if target == self.root.backing_sub
                else None
            )
            if surface is None:
                continue
            if opcode == 1:
                self.positions[surface] = struct.unpack("<ii", body)
            if opcode in (2, 3):
                (sibling,) = struct.unpack("<I", body)
                if surface in self.order:
                    self.order.remove(surface)
                self.order.insert(self.order.index(sibling) + (opcode == 2), surface)
        return messages

    def hold(self):
        self.session.held.add(self.root.app)
        self.apply()
        return self.wire()

    def release(self):
        self.session.held.clear()
        self.apply()
        return self.wire()

    def test_hold_never_expands_surface_bounds(self):
        self.hold()
        self.assertEqual(self.positions[self.question.server_id], (70, 180))
        self.assertEqual(self.root.geometry, (0, 0, 360, 480))

    def test_hold_occludes_original_question(self):
        self.hold()
        self.assertLess(
            self.order.index(self.question.server_id),
            self.order.index(self.root.backing),
        )
        self.assertGreater(
            self.order.index(self.background.server_id),
            self.order.index(self.root.backing),
        )

    def test_release_restores_order_without_input(self):
        self.hold()
        self.release()
        self.assertEqual(
            self.order,
            [
                self.root.backing,
                self.root.server_id,
                self.background.server_id,
                self.question.server_id,
            ],
        )
        self.assertFalse(self.question.hidden)

    def test_position_updates_are_forwarded_while_held(self):
        self.hold()
        self.session.request(32, 1, struct.pack("<ii", 80, 190))
        self.apply()
        self.wire()
        self.release()
        self.assertEqual(self.positions[self.question.server_id], (80, 190))

    def test_restack_updates_preserved_while_held(self):
        self.hold()
        self.session.request(32, 3, self.u(20))
        self.apply()
        self.wire()
        self.assertLess(
            self.order.index(self.question.server_id),
            self.order.index(self.root.backing),
        )
        self.release()
        self.assertLess(
            self.order.index(self.question.server_id),
            self.order.index(self.background.server_id),
        )
        self.assertGreater(
            self.order.index(self.question.server_id),
            self.order.index(self.root.backing),
        )

    def test_below_parent_order_restored(self):
        self.session.request(32, 3, self.u(10))
        self.apply()
        self.wire()
        self.hold()
        self.release()
        self.assertEqual(
            self.order,
            [
                self.root.backing,
                self.question.server_id,
                self.root.server_id,
                self.background.server_id,
            ],
        )

    def test_hidden_layer_removal(self):
        self.hold()
        self.session.request(32, 0, b"")
        self.release()
        self.assertNotIn(self.question, self.root.children)
        self.assertNotIn(self.question, getattr(self.root, "stack", []))

    def test_repeated_questions_keep_buffers_and_bounds(self):
        for _ in range(50):
            messages = self.hold() + self.release()
            self.assertTrue(self.question.has_buffer)
            self.assertEqual(self.positions[self.question.server_id], (70, 180))
            self.assertFalse(
                any(
                    target == self.question.server_id and op in (0, 1)
                    for target, op, body in messages
                )
            )

    def test_restack_invalidates_offscreen_cache(self):
        for messages in (self.hold(), self.release()):
            self.assertIn(
                (self.root.backing, 1, struct.pack("<Iii", self.session.black, 0, 0)),
                messages,
            )
            self.assertIn(
                (self.root.backing, 2, struct.pack("<iiii", 0, 0, 1, 1)), messages
            )
            self.assertIn((self.root.backing, display.COMMIT, b""), messages)

    def test_unchanged_order_does_not_reattach_backing(self):
        self.session.request(32, 2, self.u(20))
        self.apply()
        messages = self.wire()
        self.assertFalse(
            any(
                target == self.root.backing and op == 1 for target, op, body in messages
            )
        )

    def test_unrelated_app_stays_visible(self):
        self.session.held.add("com.other")
        self.apply()
        self.wire()
        self.assertFalse(self.question.hidden)
        self.assertGreater(
            self.order.index(self.question.server_id),
            self.order.index(self.background.server_id),
        )


if __name__ == "__main__":
    unittest.main()
