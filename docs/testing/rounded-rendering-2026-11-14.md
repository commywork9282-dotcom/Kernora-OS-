# Circular edges at low resolution

The reported symptom is a stepped circular silhouette in several parts of the
desktop, including app icons. Not every circular surface is an SVG: account
pictures and interaction effects also use QML rectangles and offscreen masks.

Qt can choose MSAA when a multisampled surface is requested. In this mode its
rectangle/image scene-graph nodes do not generate their own antialiased edge
geometry. Unsampled surfaces, including offscreen layers, can therefore lose
antialiasing. This was reproduced in an isolated QEMU Live session with Qt
6.8.2: forcing the MSAA path without a sampled surface produced seven failed
pixel checks and zero intermediate pixels around those circular edges.

Kernora's existing Plasma startup environment now selects
`QSG_ANTIALIASING_METHOD=vertex`. That policy uses geometric edge blending for
ordinary surfaces and offscreen layers without depending on MSAA. Avatar and
interaction masks explicitly keep antialiasing and smooth texture sampling.
AppIcon also disables standard-size snapping so a requested 52px SVG remains
52px. No theme SVG is replaced with a PNG.

A second failure was found at 75% scaling. When the shared icon components
only supplied implicit dimensions, Kirigami's painted geometry could exceed
the item's bounds: a requested 52px application icon reported a 69px painted
width, and the symbolic-icon pixel check sampled the wrong-sized silhouette.
MIcon and AppIcon now provide default explicit width/height as well as their
implicit layout hints. Instance sizing and layouts can still override them.
The same 75% cases are rerun with the expected footprint and antialiased edge.

The regression runner sources the actual startup environment, and the negative
control can bypass it. It covers avatars, icon backgrounds, ripple clipping
and repeated presses, application SVGs, symbolic SVGs, and the real menu's
44px DrawerTile. Each image is checked for intermediate edge shades, visible
content, and absence of leakage outside its expected circular boundary.

The ordinary renderer already passed the original tests before these changes.
The fix addresses the reproduced renderer failure and makes the policy
consistent; it is not a diagnosis of a specific laptop's GPU configuration.
Physical-device confirmation remains separate from these controlled tests.

Final validation: 13 checks passed at each of 75%, 100%, 125%, 150% and 200%
on an 800x600 output; all 13 also passed at 100% on 1024x600. Desktop source
checks passed. Logs, raw pixel captures, source hashes and the negative control
are under `out/test-logs/rounded-edges/2026-11-14`. The labelled six-times
pixel enlargement in `out/previews/rounded-edges/comparison.png` compares the
controlled MSAA failure with the corrected avatar contour.

The environment change takes effect after a new graphical login. The approved
update is packaged as kernora-desktop 1.4.78 with release notes in kernora-apps
1.1.88. The pending installer investigation is excluded from this update.

The built DEBs were installed into an isolated QEMU Live session and the same
78 checks passed again using the installed components. Installed file hashes
match these sources. The Calamares payload is identical to 1.4.77 apart from
its changelog. A signed staging archive passed real APT checks for stable,
stable with demo enabled, older installed versions and fresh package state;
all selected desktop 1.4.78 and apps 1.1.88 at priority 900. Existing packages
and sources outside these two source packages were preserved byte for byte.

References:

- [Qt 6.8 scene graph antialiasing](https://doc.qt.io/qt-6.8/qtquick-visualcanvas-scenegraph-renderer.html)
- [Qt 6.8 offscreen-layer limitations](https://doc.qt.io/qt-6.8/qml-qtquick-shadereffectsource.html)
- [Qt 6.8 rectangle antialiasing](https://doc.qt.io/qt-6.8/qml-qtquick-rectangle.html)
- [Kirigami icon sizing](https://api.kde.org/qml-org-kde-kirigami-primitives-icon.html)
- [Kirigami icon painted geometry](https://invent.kde.org/frameworks/kirigami/-/blob/v6.13.0/src/primitives/icon.cpp)
