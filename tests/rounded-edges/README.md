# Rounded edge rendering checks

Run `tests/rounded-edges/run.sh` in a Kernora graphical session with
`qml-qt6`, `qt6-declarative-dev-tools` and `qml6-module-qttest` installed.
The runner copies the actual Avatar, IconCircle and MStateLayer sources into
an isolated test directory; it uses the installed Material module for tokens.
It does not replace the installed desktop or account picture.

The opaque SVG fixture isolates the mask from any antialiasing already baked
into a photograph. Pixel checks require intermediate edge shades, visible
content at the centre, and no content outside the circular boundary. They
cover avatars at 32, 52 and 104 logical pixels, ordinary icon backgrounds,
and active press effects. A separate check presses, releases and presses
again, checking that each ripple appears and then fades completely.

Use `QT_SCALE_FACTOR=1`, `1.25`, `1.5` and `2` for the scale matrix. The log
records the actual capture dimensions because the session may already apply
a display scale. The black scene background prevents fractional capture
rounding from including an unrelated window background pixel.

Set `KERNORA_EDGE_CAPTURE_DIR` to retain the raw PNG captures. The test checks
the Qt Quick RHI rendering path; shader effects require that rendering path.
