# Files preview — 2026-11-05

Local preview based on demo commit `bc2c950affa004a34f26225991870d13f35ded4a`. The owner approved publication on 2026-11-06. The preview itself was not published; this release adds Files to stable 1.1.64.6 and demo 1.1.80, with English and Russian What's New notes. No new GitHub Release is required.

## Behavior

- Tabs have independent folder history, selection, search and scroll position. Ctrl+T opens a tab, Ctrl+W closes one, Ctrl+Tab / Ctrl+Shift+Tab and Ctrl+PgDown / Ctrl+PgUp switch tabs. Middle-clicking a folder opens a background tab; its context menu can open a foreground tab.
- Ctrl/Shift clicks, Shift+arrow range selection, Ctrl+arrow focus movement, Ctrl+Space, Ctrl+A, checkboxes and a selection mode are available. Empty-space dragging selects a rectangle and scrolls near the viewport edges. Escape clears selection; Ctrl+Shift+A toggles selection mode.
- Native file URL drags support groups and folder, background, breadcrumb, place and tab targets. Hovering another tab switches to it. Drop offers Copy here / Move here / Cancel and names the destination. Name conflicts reuse Replace / Keep both / Skip. A cut clipboard is consumed only after a successful move.
- Local destinations are validated before transfer, including canonical paths for self/descendant checks through symlinks. Trash contents use the existing restore/trash actions rather than direct writes into the physical trash directory. Remote URL transfers are outside this preview's scope.
- English and Russian labels are included. Shared file chooser delegates keep the new interactions disabled by default.

## Validation

The final package was built with `scripts/build-kernora-apps-binary`; source and binary package checks passed. It was installed into a disposable QEMU Live session with Qt 6.8.2. The test launcher compared the installed QML byte-for-byte with the reviewed sources before running the suite; no QML overlay was used for that final run.

`tests/files`: **21 passed, 0 failed**, including setup/teardown. Coverage includes real KIO copy/move and conflict outcomes, encoded names, invalid targets, cut clipboard cancellation, list/grid selection, keyboard handlers, independent and rapidly switched tabs, differing search filters in the same folder, and the normal file chooser. Native incoming Qt MIME drag/drop events are delivered to the actual window. See `tests/files/README.md` for reproduction.

Physical mouse/key input through QEMU additionally checked:

1. Shift+Right range selection in the real Files window.
2. Drag two selected files to Exports, choose Copy, verify both source files remain and both copies match their expected bytes.
3. Hold that group over Projects until the tab activates, drop in the empty folder, choose Move, verify sources disappear and both destination contents match. Copies in Exports remain intact.
4. Start another group drag, hover another tab and cancel with Escape; verify both files and copies remain intact and the same Files process stays alive.

The tab-hover test initially exposed a Qt abort: a delegate's QML signal handler remained active across synchronous `QDrag::exec` while navigation destroyed the delegate. Native drag startup now runs on a queued C++ timer with guarded window/drag pointers, outside the QML handler. Saving a tab no longer resets the tab strip's model. The copy, tab-hover move and cancellation checks above passed after that fix.

Artifacts are under `out/previews/files` and `out/test-logs/files`. These runs used a virtual GPU and local temporary files; they do not establish behavior on every physical desktop or network filesystem.
