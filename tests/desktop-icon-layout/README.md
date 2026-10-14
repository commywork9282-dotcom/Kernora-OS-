# Desktop icons and widgets

Run the dependency-free placement regression with:

```sh
node tests/desktop-icon-layout/placement.cjs
```

It exercises 2,000 deterministic layouts, both grid flows and text directions,
manual and automatic placement, multiple obstacles and overflow. Checks cover
unique destinations, source conservation, obstacle avoidance, stability of
unaffected manual positions and idempotence.

`audit.qml.inc` is a disposable-VM diagnostic fixture, not a shipped component.
Insert it before the final brace of `FolderView.qml` only in a test VM. It uses
a host HTTP bridge at `10.0.2.2:8765`: POST `icon-layout-audit.json` records actual
Plasma delegates and widget rectangles; GET `icon-layout-command.json` receives
commands with a changing numeric `id` and `action`. Supported actions are
`geometry`, `save`, `sort`, `flow`, `rtl`, `select` and `move`.

Wait for animated geometry to settle before issuing a separate `save` command.
Otherwise Plasma's layout manager can snap a widget back to its old position.
Restore the pristine KDE file before first installing the package, so its dpkg
diversion does not preserve instrumentation. Restore the packaged production
file after the test. Never install the fixture on a user's desktop.

Native test evidence is recorded under `out/test-logs/desktop-icon-layout/`.
See `docs/DESKTOP_ICON_LAYOUT.md` for the tested environment and results.
