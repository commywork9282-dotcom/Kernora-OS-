# Rounded edge rendering checks

Run `tests/rounded-edges/run.sh` in a Kernora graphical session with
`qml-qt6`, `qt6-declarative-dev-tools` and `qml6-module-qttest` installed.
The runner copies the actual Avatar, IconCircle, AppIcon, MIcon, MStateLayer
and launcher DrawerTile sources into an isolated test directory; it uses the
installed Material module for tokens. It applies the shipped Plasma rendering
environment before starting Qt, including the vertex antialiasing policy.
It does not replace the installed desktop or account picture.

The opaque SVG fixture isolates the mask from any antialiasing already baked
into a photograph. Pixel checks require intermediate edge shades, visible
content at the centre, and no content outside the circular boundary. They
cover avatars at 32, 52 and 104 logical pixels, ordinary icon backgrounds,
and active press effects. SVG checks cover a 52px application icon, a 24px
symbol and the actual launcher's 44px delegate. They also check that application
icons retain their requested size instead of snapping to a smaller standard or
exceeding their bounds with a device pixel ratio below one.
A separate check presses, releases and presses
again, checking that each ripple appears and then fades completely.

Use `QT_SCALE_FACTOR=0.75`, `1`, `1.25`, `1.5` and `2` for the scale matrix. The log
records the actual capture dimensions because the session may already apply
a display scale. The black scene background prevents fractional capture
rounding from including an unrelated window background pixel.

Set `KERNORA_EDGE_CAPTURE_DIR` to retain the raw PNG captures. The test checks
the Qt Quick RHI rendering path; shader effects require that rendering path.

To reproduce the fault without applying the session defaults, run a negative
control:

```sh
QSG_ANTIALIASING_METHOD=msaa KERNORA_EDGE_RAW_RENDERER=1 tests/rounded-edges/run.sh
```

This deliberately selects MSAA without a multisampled surface. Seven circular
geometry/mask cases then have no intermediate edge pixels and must fail. Run
again without `KERNORA_EDGE_RAW_RENDERER`: sourcing the real session policy
selects vertex AA and the same cases pass. SVG rasterization remains a separate
part of the checks. The injected fault is a controlled renderer configuration,
not evidence that a particular community laptop used that configuration.
