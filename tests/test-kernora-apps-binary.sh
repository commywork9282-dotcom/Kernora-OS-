#!/usr/bin/env bash
set -Eeuo pipefail

project_root=$(CDPATH= cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)
package_root="$project_root/packages/native/kernora-apps"
package_version=$(dpkg-parsechangelog -l"$package_root/debian/changelog" -S Version)
deb="$project_root/_build/binary-packages/kernora-apps_${package_version}_amd64.deb"

fail() {
  printf 'kernora-apps binary test: %s\n' "$*" >&2
  exit 1
}

[[ -s "$deb" ]] || fail "binary package does not exist: $deb"
[[ "$(dpkg-deb --field "$deb" Architecture)" == "amd64" ]] || fail "wrong architecture"
[[ "$(dpkg-deb --field "$deb" Version)" == "$package_version" ]] || fail "wrong version"

temporary_root=$(mktemp -d /tmp/kernora-apps-test.XXXXXX)
trap 'find "$temporary_root" -depth -delete' EXIT
dpkg-deb --extract "$deb" "$temporary_root"

for dependency in flatpak appstream libflatpak0 libappstreamqt3; do
  dpkg-deb --field "$deb" Depends | grep -Eq "(^|, )$dependency( |,|$)" || fail "missing dependency: $dependency"
done
for path in usr/share/kernora/store/featured.json usr/share/flatpak/remotes.d/flathub.flatpakrepo etc/apt/apt.conf.d/60kernora-store usr/share/knotifications6/kernora-store.notifyrc usr/lib/x86_64-linux-gnu/qt6/qml/org/kernora/store/qmldir usr/lib/x86_64-linux-gnu/qt6/qml/org/kernora/store/libkernorastore.so; do
  [[ -s "$temporary_root/$path" ]] || fail "missing Store file: $path"
done
qml=usr/lib/x86_64-linux-gnu/qt6/qml/org/kernora/system
for path in "$qml/qmldir" "$qml/libkernorasystem.so" usr/share/knotifications6/kernora-screenshot.notifyrc \
  usr/share/knotifications6/kernora-updates.notifyrc \
  usr/lib/x86_64-linux-gnu/qt6/qml/org/kernora/shell/qmldir \
  usr/lib/x86_64-linux-gnu/qt6/qml/org/kernora/shell/libkernorashell.so; do
  [[ -s "$temporary_root/$path" ]] || fail "missing $path"
done
for app in settings files welcome editor photos player calculator screenshot store share taskmanager; do
  [[ -x "$temporary_root/usr/bin/kernora-$app" ]] || fail "missing kernora-$app"
  [[ -s "$temporary_root/usr/share/kernora/$app/Main.qml" ]] || fail "missing the $app interface"
  cmp -s "$package_root/apps/$app/qml/Main.qml" "$temporary_root/usr/share/kernora/$app/Main.qml" || fail "$app interface differs from the source"
  [[ -s "$temporary_root/usr/share/applications/org.kernora.$app.desktop" ]] || fail "missing the $app desktop entry"
done
grep -q 'X-KDE-DBUS-Restricted-Interfaces=org.kde.KWin.ScreenShot2' \
  "$temporary_root/usr/share/applications/org.kernora.screenshot.desktop" \
  || fail "Screenshot cannot ask KWin for screenshots"
cmp -s "$temporary_root/usr/share/applications/org.kernora.taskmanager.desktop" "$temporary_root/usr/share/kglobalaccel/org.kernora.taskmanager.desktop" \
  && grep -qx 'X-KDE-Shortcuts=Ctrl+Shift+Esc,Ctrl+Esc' "$temporary_root/usr/share/kglobalaccel/org.kernora.taskmanager.desktop" \
  || fail "Ctrl+Shift+Esc does not open the Task Manager"
grep -qx 'Exec=/usr/bin/kernora-screenshot' \
  "$temporary_root/usr/share/applications/org.kernora.screenshot.desktop" \
  || fail "Screenshot's Exec is not an absolute path; KWin would refuse it"

for domain in settings files editor photos player calculator screenshot welcome system update-notifier store share taskmanager; do
  [[ -s "$temporary_root/usr/share/locale/ru/LC_MESSAGES/kernora-$domain.mo" ]] \
    || fail "Russian translation is missing: kernora-$domain"
done
grep -qx 'Exec=kernora-welcome --first-run' \
  "$temporary_root/etc/xdg/autostart/org.kernora.welcome.desktop" \
  || fail "Welcome is not started at login"
[[ -x "$temporary_root/usr/bin/kernora-update-notifier" ]] || fail "missing kernora-update-notifier"
grep -qx 'Exec=kernora-update-notifier' \
  "$temporary_root/etc/xdg/autostart/org.kernora.update-notifier.desktop" \
  || fail "the update notifier is not started at login"
grep -qx 'DesktopEntry=org.kernora.settings' "$temporary_root/usr/share/knotifications6/kernora-updates.notifyrc" \
  || fail "update notifications would not come from Settings"
python3 - "$temporary_root/usr/share/kernora/whatsnew.json" <<'PYTHON_TEST' || fail "the release notes for What's new are missing or broken"
import json, sys
releases = json.load(open(sys.argv[1], encoding="utf-8"))
assert releases and all(r["id"] and r["items"] for r in releases)
ids = [r["id"] for r in releases]
assert ids == sorted(ids, reverse=True), "newest release first"
for item in (i for r in releases for i in r["items"]):
    assert item["icon"] and item["title"]["en"] and item["title"]["ru"] and item["text"]["en"] and item["text"]["ru"]
PYTHON_TEST
grep -q 'kernora-settings' "$temporary_root/usr/bin/systemsettings" \
  || fail "the systemsettings wrapper is missing"
grep -Fxq 'License: MPL-2.0' "$temporary_root/usr/share/kernora/copyright/librewolf" \
  || fail "the LibreWolf copyright summary is missing"
[[ -x "$temporary_root/usr/lib/x86_64-linux-gnu/libexec/kernora-filechooser" ]] \
  || fail "the file chooser backend is missing"
[[ -s "$temporary_root/usr/share/kernora/filechooser/Chooser.qml" ]] || fail "the file chooser window is missing"
grep -qx 'Exec=/usr/lib/x86_64-linux-gnu/libexec/kernora-filechooser' \
  "$temporary_root/usr/share/dbus-1/services/org.freedesktop.impl.portal.desktop.kernora.service" \
  || fail "D-Bus cannot start the file chooser"
grep -q 'org.freedesktop.impl.portal.FileChooser' "$temporary_root/usr/share/xdg-desktop-portal/portals/kernora.portal" \
  || fail "the file chooser portal is not declared"
grep -qx 'org.freedesktop.impl.portal.FileChooser=kernora;kde;' "$temporary_root/etc/xdg-desktop-portal/kde-portals.conf" \
  || fail "the portal does not use the Kernora file chooser under Plasma"
grep -qx 'default=kde' "$temporary_root/etc/xdg-desktop-portal/kde-portals.conf" \
  || fail "the other portals no longer come from KDE"
grep -qx 'export PLASMA_INTEGRATION_USE_PORTAL=1' "$temporary_root/etc/xdg/plasma-workspace/env/kernora-file-dialogs.sh" \
  || fail "Qt programs do not use the portal for their file dialogs"
grep -qx 'wmclass=org.kernora.filechooser' "$temporary_root/etc/xdg/kwinrulesrc" \
  || fail "the file chooser has no window rule"
control=$(mktemp -d /tmp/kernora-apps-control.XXXXXX)
dpkg-deb --control "$deb" "$control"
grep -q 'dpkg-divert --package kernora-apps --add --rename' "$control/preinst" \
  || fail "systemsettings is not diverted before the wrapper is unpacked"
grep -q 'dpkg-divert --package kernora-apps --remove --rename' "$control/postrm" \
  || fail "the systemsettings diversion is not removed with the package"
find "$control" -depth -delete

printf 'kernora-apps binary test: OK\n'
