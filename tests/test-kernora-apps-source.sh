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
[[ "$version" == "1.1.18" ]] || fail "unexpected source version"
[[ "$(dpkg-parsechangelog -l"$package_root/debian/changelog" -S Distribution)" == "UNRELEASED" ]] \
  || fail "development package must remain UNRELEASED"
[[ "$(<"$package_root/debian/source/format")" == "3.0 (native)" ]] || fail "wrong source format"
[[ -x "$package_root/debian/rules" ]] || fail "debian/rules is not executable"
grep -Fxq 'Package: kernora-apps' "$package_root/debian/control" || fail "binary stanza is missing"

for app in settings files welcome editor photos player calculator screenshot; do
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

printf 'kernora-apps source test: OK\n'
