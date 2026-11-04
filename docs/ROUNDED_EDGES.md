# Rounded edge rendering

The reported account picture reproduced a mask bug rather than a low resolution
source image. Qt Quick's MultiEffect remaps mask alpha through a threshold and
spread. The defaults produced a hard cut: the opaque-image fixture had zero
intermediate edge shades at 32, 52 and 104 logical pixels. With the corrected
mask the 52-pixel fixture had 200 intermediate edge pixels in the baseline
capture, while retaining an opaque centre and a clean exterior.

Avatar masks now use `maskThresholdMin: 0.5` and `maskSpreadAtMin: 1.0`, matching
Kernora's existing RoundedClip component. The change covers the shared Avatar
(Settings and launcher), SDDM, the lock screen and the logout/power menu.
The original pictures are not resized or rewritten by this fix.

The common MStateLayer uses the same smooth mask. Its source and mask source
are connected when the effect becomes visible, after their layers activate.
This also avoids selecting an inactive texture proxy on the first press.
The layers still turn off when the ripple fades. No global MSAA setting,
shader backend override or supersampling is added to the installed session.

Relevant Qt 6.8 references:

- [MultiEffect mask properties](https://doc.qt.io/qt-6.8/qml-qtquick-effects-multieffect.html)
- [Qt 6.8.2 mask shader](https://github.com/qt/qtdeclarative/blob/v6.8.2/src/effects/data/shaders/multieffect.frag)

## Validation

`tests/rounded-edges/run.sh` renders the actual sources in a Kernora graphical
session. Its opaque SVG separates the mask from any alpha already baked into
a picture. Pixel checks cover three avatar sizes, two icon container sizes and
two press-effect sizes. A lifecycle check presses and releases twice, requiring
a visible effect during each press and a fully clear result after each release.

In QEMU with Qt 6.8.2 and the OpenGL RHI rendering path, all ten cases passed at
each of `QT_SCALE_FACTOR=1`, `1.25`, `1.5` and `2`: 40 passes, no failures.
The session has its own display scaling, so logs record actual raster sizes.
The original Avatar fails the edge-shade check, and the original press effect
fails the visible-content check. Ordinary circle backgrounds remain smooth.

Raw captures and logs are in `out/test-logs/rounded-edges/` and the explicitly
labelled four-times enlargement of a 52-pixel account picture is saved as
`out/previews/rounded-edges/before-after.png`. The comparison uses both actual
Avatar implementations with the same stock image; it is not an AI mockup.

Binary-package validation compares every bundled MStateLayer copy and each
changed avatar screen against its source. Stable uses desktop/calamares
1.4.55.2 and apps 1.1.64.2. Demo retains its existing features and uses
1.4.66 / 1.1.76 so installed demo packages also have a higher upgrade candidate.
Both channels include the English/Russian What's New entry `2026-11-03-2`.

The final stable desktop package was installed over 1.4.55.1 in the disposable
VM and `dpkg --audit` was clean. Settings loaded with the stock layered avatar.
The installed SDDM theme was opened using `sddm-greeter-qt6 --test-mode`, and
the installed lock screen using `kscreenlocker_greet --testing`; both rendered
their account picture and input controls. Runtime logs and screenshots are
stored alongside the pixel tests. These tests do not authenticate a real user.
