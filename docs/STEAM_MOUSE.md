# CS2: cursor escapes to a second monitor

Reported configuration: Steam installed through Kernora Store, CS2 in
fullscreen, two monitors. Moving toward the other monitor and firing can
click outside the game. The Steam source, GPU, game build and launch options
are unknown; the diagnosis does not assume those details.

Store installs the repository's Steam package without rewriting its game
files or display/input permissions. The default source selection prefers
Flathub when that catalogue entry is available. It does not add gamescope,
force a display backend or change SDL mouse settings.

A launch-selection bug was reproduced separately: a native desktop entry
could shadow an installed Flatpak application. Version 1.1.30 executed the
native fixture; 1.1.31 executes `flatpak run --system` with the installed
full app ref. The real Flatpak CLI also accepted that ref in the test VM.
Native applications now use their Debian AppStream launchables and reject
Flatpak desktop entries. This fixes source selection; it is not proof that
the reported CS2 pointer issue is fixed.

Related upstream reports:

- https://github.com/ValveSoftware/csgo-osx-linux/issues/3856
- https://github.com/ValveSoftware/csgo-osx-linux/issues/4354
- https://github.com/libsdl-org/SDL/pull/16267

These reports describe different mouse failures and must not be treated as
a confirmed diagnosis of this user's issue. CS2 ships its own SDL copy;
a system SDL update alone does not replace it. Automatically forcing all
Steam games to a different backend or replacing their libraries would need
separate compatibility testing.

A separate QEMU/KVM check used two adjacent 1280×800 outputs, Plasma
Wayland/KWin 6.3.6 and Xwayland 24.1.6. An SDL 2.32.4 fullscreen X11
probe enabled relative mouse mode and window grab. Injected relative
movement and a button event reached the probe; it retained focus and
reported zero focus losses. This checks basic confinement in the shipped
desktop, not CS2 or the reporter's GPU/input configuration. CS2 itself
was not run, so its reported cursor escape remains unverified.

Flatpak launch preserves the exported desktop entry's GPU preference and
startup metadata and application-specific command arguments while selecting the installed scope/ref explicitly.
Desktop-file changes are made in memory only. D-Bus activation is disabled
for this launch so it cannot bypass the selected installation.
