# Android permission window regression

Run the protocol regressions on the host:

```sh
python3 tests/android-permissions/run.py
```

The optional argument selects another `kernora-android-display` implementation,
for example an unmodified copy for the negative control. Tests drive its actual
Wayland requests and inspect the resulting coordinates, stacking requests,
buffer lifetime and redraw of the immutable backing buffer. They include
repeated questions, changes while held, below-parent stacking, removal, unrelated
apps and unchanged order. The desktop source check runs this suite too.

For visual verification, use a disposable Kernora Plasma Wayland VM with the
rounded-corners effect loaded. Stop Android's display/session services in that
VM if they are running. With the repository mounted or copied into it, run as
the graphical user:

```sh
python3 tests/android-permissions/visual-proxy.py packages/native/kernora-desktop/data/android/kernora-android-display
```

In another terminal of that VM:

```sh
python3 tests/android-permissions/visual-client.py
printf 'hold com.example.permissiontest\n' > "$XDG_RUNTIME_DIR/kernora-android-ready"
printf 'release com.example.permissiontest\n' > "$XDG_RUNTIME_DIR/kernora-android-ready"
```

Capture between hold and release. Green is the app's static main layer, yellow
is the original Android permission layer, and blue is a separate Linux client
that connects directly to KWin. Hold must hide yellow while preserving green;
release must restore yellow without mouse or keyboard input. The proxy only
bypasses desktop-entry indexing delays; its graphics code is the source under
test. No Android image or network download is needed for this reproduction.

These helpers occupy the Android display socket and FIFOs, so run them only in
the disposable VM. Stop both helpers when finished.

The recorded investigation and physical-device limitation are in
`docs/testing/android-permissions-2026-11-22.md`.
