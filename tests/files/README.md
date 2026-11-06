# Files interaction checks

Run in a disposable Kernora session with the preview `kernora-apps` package, `qml6-module-qttest`, `libqt6quicktest6` and the usual desktop runtime installed. Build the runner with Qt 6 development packages and KF6 I18n:

```sh
cmake -S tests/files -B /tmp/kernora-files-tests-build
cmake --build /tmp/kernora-files-tests-build -j2
/tmp/kernora-files-tests-build/files-tests -input tests/files -o /tmp/files-results.txt,txt
```

The QML imports the installed Files interface from `/usr/share/kernora/files`. Install the package being checked first. Use a disposable user: the suite switches the Files view preference between grid and list and uses the normal file chooser.

Each test owns a `QTemporaryDir`. Fixtures and KIO copy/move operations stay inside it. Tests cover mouse selection, keyboard handlers, checkboxes, rectangle selection, tab navigation, independent history/search/selection/scroll, rapid switches, middle-click, the shared file chooser, Unicode/reserved file names, collision handling, cancellation and cut clipboard retention. Incoming native Qt drag/drop events exercise the actual window and MIME URL handling, including rejection of invalid destinations and unsupported actions. Arrow key events target the view directly because compositor focus cannot be guaranteed for temporary windows; shortcuts go through Qt Quick Test.

This suite does not simulate a compositor drag initiated by the native `QDrag` source. Verify that path separately using physical pointer events in QEMU or a desktop session, including selection of multiple files, dropping into a folder, hovering another tab, cancellation, copy and move. Check contents and source existence after the operation.
