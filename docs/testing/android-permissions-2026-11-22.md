# Black windows during Android permission questions

The community recording shows Chat's notification permission question at
approximately 85–90 seconds. The native Kernora question remains visible while
the Android window behind it becomes completely black, including its title
bar. The desktop is still running. The separate report also mentions Discord
and the desktop shell; that part is not demonstrated in the supplied clip.

## Reproduced cause

`kernora-android-display.hide_questions()` previously moved the smaller Android
layers to −32000, −32000 during a native question. Subsurfaces are not clipped to
xdg window geometry. Moving them this far expanded the window's visible bounds,
which KWin's rounded-corners offscreen effect uses to size its texture.

In an isolated QEMU Live session, a static green 360×480 app layer and yellow
220×120 question layer reproduced the completely black window with the
unmodified source. KWin recorded:

- `GL_INVALID_VALUE in glTexStorage2D(invalid width, height or depth)`
- `GL_FRAMEBUFFER_INCOMPLETE_ATTACHMENT`
- `GL_INVALID_OPERATION in glBindFramebuffer(non-gen name)`

The last negative-control errors occurred at 20:37:01 guest UTC. No further
instances occurred during the corrected runs. A separate Linux client and
Plasma remained visible in this VM. A broader effect on other windows on the
reporter's hardware is plausible given the compositor error, but was not
reproduced here.

## Correction

Keep the layers at their original coordinates. Move hidden question layers
below the proxy's opaque backing surface, preserving Android's requested order
above and below the parent. Track order changes while held and restore the
latest order on release. Remove destroyed layers from this bookkeeping.

Restacking alone was insufficient with KWin's offscreen effect: its cached
window image stayed unchanged until the client submitted another buffer.
Damage without a buffer attach was insufficient too. Reattaching the proxy's
own immutable black 1×1 backing buffer, damaging it and committing it causes
KWin to invalidate that cache immediately. App buffers are never detached,
copied or replayed. Unchanged stacking requests do not trigger extra backing
updates.

## Validation

- Source baseline: `7d4955a`, plus this local Android change.
- QEMU/KVM, 1280×800, Plasma Wayland, software rendering through virtio-vga.
- Live packages: desktop 1.4.77, apps 1.1.87, KWin 6.3.6,
  rounded-corners 0.11.0+kernora1. The display proxy was loaded from the current
  source, not an older installed copy; its collected hash matches the workspace.
- All 11 protocol regressions pass. The negative control fails the coordinate,
  hiding, restacking and cache-redraw checks.
- Full `tests/test-kernora-desktop-source.sh` passes.
- 20 hold/release cycles against the actual KWin session; 36 sampled frames:
  minimum 130,000 green app pixels and 48,000 blue Linux-client pixels. 19 frames
  show the question hidden and 17 show it visible. No black app frame occurred.
- Final stationary captures: before fix 0 green pixels; fixed hold 156,400;
  fixed release 130,000, with 21,525 yellow question pixels restored. No mouse
  or keyboard input was sent between the hold and release captures.
- The installed `kernora-androiddialog` displayed a real QML question over the
  fixed app layers; Escape returned exit code 10 and released the hold.
- PowerDevil was stopped and DPMS turned on before the final repeat run to
  prevent ordinary idle screen blanking from affecting capture checks.

Evidence, source hashes, negative control, exact VM helpers and logs:
`out/test-logs/android-permissions/2026-11-22/`.

Actual framebuffer crops are in
`out/previews/android-permissions/comparison.png`; the native question capture
is `out/previews/android-permissions/permission-dialog.png`.

This tests the reproduced Wayland/compositor mechanism and real Kernora QML
question. It does not run the reporter's full Chat/Waydroid container or GPU.
Confirmation on that machine remains necessary. The initial investigation was
local; publication was authorized afterwards by the user.

Primary implementation references:

- [KWin 6.3 offscreen texture allocation](https://github.com/KDE/kwin/blob/Plasma/6.3/src/effect/offscreeneffect.cpp)
- [KWin 6.3 surface buffer/damage handling](https://github.com/KDE/kwin/blob/Plasma/6.3/src/wayland/surface.cpp)
- [Wayland subsurface stacking protocol](https://wayland.freedesktop.org/docs/html/apa.html#protocol-spec-wl_subsurface)

## Approved update validation

The release is based on published main `9055951`, preserving Claude's later
work. The Android display code is unchanged between the investigation base
and that published base. New packages are desktop/calamares configuration
1.4.86 and apps 1.1.97, with English and Russian What's New dated 2026-11-22.
The pending local avatar and installer investigations are excluded.

Both source checks and both binary checks pass. The DEBs install cleanly over
desktop 1.4.85 / apps 1.1.96 in a disposable November 19 Live image, followed by
a fresh Plasma Wayland session. All 11 regressions pass using the installed
display script and protocols. Another 20 cycles and 36 framebuffer samples
pass, with minimum 130,000 green and 48,000 blue pixels; 19 hidden and 17
visible question samples. The native dialog exits with code 10 on Escape,
`dpkg --audit` is empty, and KWin records no invalid-texture/framebuffer errors.
The installed script hash matches the approved source.

The Calamares configuration payload differs from published 1.4.85 only in its
compressed changelog. All 30 unrelated pool files are preserved byte for byte.
Both APT suites verify with the shipped archive key; package and manifest
hashes verify. Real APT chooses desktop 1.4.86, apps 1.1.97 and configuration
1.4.86 for stable and stable with demo, with fresh and previously installed
package state. Demo is empty and the update belongs to stable.

Release build, package installation, framebuffer and APT logs are under
`out/test-logs/android-permissions/release-2026-11-22/`.
After installation, sign out and back in, or restart, to load the new display
service; running Android applications are not forcibly closed by the update.
