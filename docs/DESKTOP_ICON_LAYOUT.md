# Desktop icons leave room for widgets

Desktop shortcuts previously used Plasma's icon grid independently of widget
placement. A shortcut could therefore be placed underneath a widget.

`KernoraIconLayout.qml` observes actual visible desktop applet geometry, maps it
into the icon grid and reserves intersecting cells with four pixels of spacing.
`IconPlacement.js` retains unaffected manual positions and moves conflicting
icons into the nearest available cells. Automatic sorting fills available cells
in source order. Both grid directions and right-to-left layout are supported.
Selection and the focused source item survive relocation. When the visible grid
is full, overflow preserves all source items rather than dropping shortcuts.

The integration uses KDE's existing FolderModel and Positioner. Manual moves
persist through the native positioner; automatic placement does not overwrite
saved manual positions. Changes are restricted to the root desktop containment,
not folder popups. Apply the update by signing out and back in.

The packaged FolderView is based on the file shipped in Kernora's Plasma 6.3.6
image, with baseline SHA256
`b308111803d996819972c879986a11da84b9cda199aa6bfce0dc6480307e3bf6`.
Its existing click handling and context-menu behavior are preserved. SPDX legal
attribution is retained, and Debian copyright records the KDE authors. The
original file is kept through a package-owned `.kde` dpkg diversion and restored
on removal. No explanatory code comments were added.

## Validation

A disposable QEMU/KVM guest ran the English Live image with Plasma 6.3.6 at
1440 × 900. With the original FolderView, a manually positioned shortcut at cell
54 overlapped the Glance widget; `baseline-overlap.png` and its JSON record show
that failure. With the fix, the same shortcut moved to the adjacent free cell.

Eleven native checks passed for selection/focus preservation, widget movement,
resizing, saving, automatic sorting, both grid flows and both text directions.
Each check inspected actual delegate rectangles after geometry settled and
verified that all 12 source items survived without intersecting widget bounds.
The standalone placement regression passed 2,000 deterministic layouts.

Package versions are `kernora-desktop` / `kernora-calamares` 1.4.29 and
`kernora-apps` 1.1.36. What's New has English and Russian entry `2026-10-13-9`.
These changes do not alter the Calamares executable or networking settings.

A real dpkg upgrade from desktop 1.4.28 / apps 1.1.35 passed in the guest.
The three installed layout files matched the package sources, the original KDE
file survived byte-for-byte in the diversion, and Plasma restarted successfully.
Four further native checks passed with 13 shortcuts: a newly created shortcut,
switching back to manual placement, an attempted placement in a reserved cell,
and saving the resulting layout. Package source/binary checks and `make verify`
passed. The current project ISO has not been rebuilt for this change.
