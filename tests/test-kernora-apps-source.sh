#!/usr/bin/env bash
set -Eeuo pipefail

project_root=$(CDPATH= cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)
package_root="$project_root/packages/native/kernora-apps"

fail() {
  printf 'kernora-apps source test: %s\n' "$*" >&2
  exit 1
}

for dependency in dpkg-parsechangelog grep; do
  command -v "$dependency" >/dev/null 2>&1 \
    || fail "required command not found: $dependency"
done

version=$(dpkg-parsechangelog -l"$package_root/debian/changelog" -S Version)
[[ "$version" == "1.1.36" ]] || fail "unexpected source version"
[[ "$(dpkg-parsechangelog -l"$package_root/debian/changelog" -S Distribution)" == "UNRELEASED" ]] \
  || fail "development package must remain UNRELEASED"
[[ "$(<"$package_root/debian/source/format")" == "3.0 (native)" ]] || fail "wrong source format"
[[ -x "$package_root/debian/rules" ]] || fail "debian/rules is not executable"
grep -Fxq 'Package: kernora-apps' "$package_root/debian/control" || fail "binary stanza is missing"

for app in settings files welcome editor photos player calculator screenshot store; do
  [[ -s "$package_root/apps/$app/qml/Main.qml" ]] || fail "$app has no interface"
  desktop="$package_root/apps/$app/org.kernora.$app.desktop"
  [[ -s "$desktop" ]] || fail "$app has no desktop entry"
  grep -Eq "^Exec=(/usr/bin/)?kernora-$app( |$)" "$desktop" \
    || fail "$app desktop entry does not start kernora-$app"
  grep -q '^Name\[ru\]=' "$desktop" || fail "$app desktop entry has no Russian name"
  grep -q '^Categories=.*KDE' "$desktop" && fail "$app is filed as a KDE application"
  [[ -s "$package_root/src/apps/$app.cpp" ]] || fail "$app has no host"
done
grep -Fxq 'X-KDE-DBUS-Restricted-Interfaces=org.kde.KWin.ScreenShot2' \
  "$package_root/apps/screenshot/org.kernora.screenshot.desktop" \
  || fail "Screenshot is not allowed to ask KWin for screenshots"

if grep -rEn 'M3\.on[A-Z]' "$package_root/apps" >/dev/null; then
  fail "QML uses an M3.on* role; use the *Content spelling"
fi

grep -Fq 'void Appearance::apply(' "$package_root/src/system/appearance.cpp" \
  && grep -Fq 'kernorarc' "$package_root/src/system/appearance.cpp" \
  || fail "Appearance cannot switch the Material generation"
grep -Fq 'page.setGeneration(value)' "$package_root/apps/settings/qml/pages/AppearancePage.qml" \
  && grep -Fq 'Appearance.setGeneration(modelData.value' "$package_root/apps/welcome/qml/Main.qml" \
  || fail "Settings and Welcome do not offer the Material generations"
grep -Fq 'Files.liveWallpapers()' "$package_root/apps/settings/qml/pages/AppearancePage.qml" \
  && grep -Fq 'Files.liveWallpapers()' "$package_root/apps/welcome/qml/Main.qml" \
  || fail "Settings and Welcome do not list the live wallpapers"
grep -Fq '!SystemInfo.live && Updates.available' "$package_root/apps/settings/qml/pages/UpdatesPage.qml" \
  && grep -Fq 'org.kernora.installer.desktop' "$package_root/apps/settings/qml/pages/UpdatesPage.qml" \
  || fail "Settings downloads updates in the live session"
[[ "$(grep -c 'Default Applications' "$package_root/src/system/defaultapps.cpp")" -ge 2 ]] \
  || fail "Settings shows a stale default app after choosing one"
[[ -s "$package_root/apps/settings/qml/pages/DriversPage.qml" ]] \
  && grep -Fq 'page.open("DriversPage.qml"' "$package_root/apps/settings/qml/pages/SystemPage.qml" \
  || fail "Settings has no Drivers page"
grep -Fq 'driverReady' "$package_root/src/updatenotifier/main.cpp" \
  && grep -Fxq '[Event/driverReady]' "$package_root/data/knotifications/kernora-updates.notifyrc" \
  || fail "nobody is told to restart after a driver install"
grep -Fxq ' pkexec,' "$package_root/debian/control" \
  || fail "Settings cannot ask for the driver actions without pkexec"
grep -Fq 'model: Qt.application.screens' "$package_root/apps/screenshot/qml/Main.qml" \
  && grep -Fq 'Screenshot.captureScreen(overlay.screen.name' "$package_root/apps/screenshot/qml/Main.qml" \
  && grep -Fq 'void Screenshot::captureScreen' "$package_root/src/system/screenshot.cpp" \
  && grep -Fq 'LayerShell.Window.screenConfiguration: LayerShell.Window.ScreenFromQWindow' "$package_root/apps/screenshot/qml/Main.qml" \
  && grep -Fxq ' qml6-module-org-kde-layershell,' "$package_root/debian/control" \
  || fail "Screenshot shows one monitor's picture on another"
grep -Fq 'new PlasmaQuick::ConfigView(applet)' "$package_root/src/shell/appletsettings.cpp" \
  && grep -Fq 'add_subdirectory(src/shell)' "$package_root/CMakeLists.txt" \
  && grep -Fxq ' libplasma-dev,' "$package_root/debian/control" \
  || fail "a widget's settings cannot open without ending edit mode"


for dependency in libappstreamqt-dev libflatpak-dev; do
  grep -Eq "^ $dependency[, ]*$" "$package_root/debian/control" || fail "missing Store build dependency: $dependency"
done
for dependency in appstream flatpak; do
  grep -Eq "^ $dependency[, ]*$" "$package_root/debian/control" || fail "missing Store runtime dependency: $dependency"
done
python3 - "$package_root" <<'PY'
import datetime, json, pathlib, sys
p = pathlib.Path(sys.argv[1])
featured = json.loads((p / 'data/store/featured.json').read_text())
assert all(isinstance(ids, list) and ids and len(ids) == len(set(ids)) for ids in featured.values())
notes = json.loads((p / 'data/whatsnew.json').read_text())
assert any(i['icon'] == 'org.kernora.store' for r in notes for i in r['items'])
for release in notes:
    datetime.date.fromisoformat(release.get('date', release['id'][:10]))
PY

printf 'kernora-apps source test: OK\n'
