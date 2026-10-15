# CS2: cursor escapes to the second monitor

Reported setup: Steam installed from Kernora Store, CS2 in fullscreen, two
monitors. Moving the mouse towards the other monitor and shooting can click
outside the game. I don't know the Steam source (Flatpak or Debian), the GPU,
the game build or launch options yet, so I'm not assuming any of that.

The Store installs Steam as is. It doesn't touch game files or display/input
permissions, and by default it prefers the Flathub version when there is one.
It doesn't add gamescope, force a display backend or change SDL mouse
settings.

While looking into this I found a separate bug: a Debian desktop entry could
win over an installed Flatpak when launching. 1.1.30 started the wrong one,
1.1.31 runs `flatpak run --system` with the exact installed app ref. Debian
apps now use their own launchers and never pick up a Flatpak entry. That
fixes which app starts, it doesn't mean the CS2 cursor thing is fixed.

Upstream reports that look related:

- https://github.com/ValveSoftware/csgo-osx-linux/issues/3856
- https://github.com/ValveSoftware/csgo-osx-linux/issues/4354
- https://github.com/libsdl-org/SDL/pull/16267

They're all slightly different mouse problems though, so none of them is
"the" answer here. Also CS2 ships its own SDL, so updating the system SDL
won't change anything for it. Forcing every Steam game onto a different
backend or swapping their libraries would need a lot of testing first.

## What I tested

A QEMU VM with two 1280×800 screens side by side, Plasma Wayland/KWin 6.3.6
and Xwayland 24.1.6. A small fullscreen SDL 2.32.4 X11 test app turned on
relative mouse mode and window grab. Mouse movement and clicks went to the app,
it kept focus and never lost it. So basic mouse grabbing works on the desktop,
but I didn't run CS2 itself, so the actual report isn't reproduced.

Something worth trying in the meantime (haven't tested it with CS2 myself)
is this as the CS2 launch option in Steam:

```
gamescope -f --force-grab-cursor -- %command%
```

Debian Steam needs `sudo apt install gamescope` for that, the Flatpak Steam
needs the gamescope extension from Flathub instead.

## Flatpak launch details

When the Store starts a Flatpak it keeps the exported desktop entry's GPU
preference, startup info and app-specific arguments, but picks the installed
scope/ref explicitly. The desktop file is only changed in memory. D-Bus
activation is turned off for that launch so it can't sneak around the chosen
installation.
