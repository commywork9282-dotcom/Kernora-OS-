# Desktop icons leave room for widgets

Desktop shortcuts used Plasma's icon grid without caring where widgets are,
so a shortcut could end up hidden under a widget. Annoying.

Now `KernoraIconLayout.qml` looks at where the visible desktop widgets
actually are, maps that onto the icon grid and reserves the cells they cover
(with 4 px of spacing). `IconPlacement.js` leaves icons that aren't in the
way alone and moves the ones that are into the nearest free cell. Automatic
sorting just fills the free cells in order. Both grid directions and
right-to-left layouts work. Selection and keyboard focus survive the move.
If the visible grid is full, the extra icons still exist, nothing gets
dropped.

It's built on KDE's own FolderModel and Positioner. Icons you move by hand
are saved the normal way, and automatic placement never overwrites them.
Only the desktop itself is affected, not folder popups. Log out and back in
after updating.

The packaged FolderView starts from the file in Kernora's Plasma 6.3.6 image
(SHA256 `b308111803d996819972c879986a11da84b9cda199aa6bfce0dc6480307e3bf6`).
Clicking and the context menu work the same as before. The KDE license
headers are kept and Debian copyright lists the KDE authors. The original file
is kept aside with a dpkg diversion (`.kde`) and comes back if you remove the
package.

## Testing

In a QEMU VM with the English Live image (Plasma 6.3.6, 1440×900), the
original FolderView let a shortcut at cell 54 sit under the Glance widget.
With the fix it moved to the next free cell.

There are 11 checks in the real desktop for selection and focus, moving and
resizing widgets, saving, sorting, both grid flows and both text directions.
Each one waits for the layout to settle and checks that all 12 icons are
still there and none overlap a widget. The standalone placement test in
`tests/desktop-icon-layout/` runs 2,000 random-but-repeatable layouts.

Then I did a real upgrade from desktop 1.4.28 / apps 1.1.35 in the VM: the
installed files matched the source, the original KDE file was intact in the
diversion and Plasma restarted fine. Four more checks with 13 shortcuts
passed: a new shortcut, switching back to manual placement, dropping an icon
on a reserved cell, and saving.

Shipped in `kernora-desktop` / `kernora-calamares` 1.4.29 and `kernora-apps`
1.1.36 (What's New entry `2026-10-13-9`), and it's in the Oct 14 ISO.
