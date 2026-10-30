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
[[ "$version" == "1.1.64" ]] || fail "unexpected source version"
[[ "$(dpkg-parsechangelog -l"$package_root/debian/changelog" -S Distribution)" == "UNRELEASED" ]] \
  || fail "development package must remain UNRELEASED"
[[ "$(<"$package_root/debian/source/format")" == "3.0 (native)" ]] || fail "wrong source format"
[[ -x "$package_root/debian/rules" ]] || fail "debian/rules is not executable"
grep -Fxq 'Package: kernora-apps' "$package_root/debian/control" || fail "binary stanza is missing"

for app in settings files welcome editor photos player calculator screenshot store share; do
  [[ -s "$package_root/apps/$app/qml/Main.qml" ]] || fail "$app has no interface"
  desktop="$package_root/apps/$app/org.kernora.$app.desktop"
  [[ -s "$desktop" ]] || fail "$app has no desktop entry"
  grep -Eq "^Exec=(/usr/bin/)?kernora-$app( |$)" "$desktop" \
    || fail "$app desktop entry does not start kernora-$app"
  grep -q '^Name\[ru\]=' "$desktop" || fail "$app desktop entry has no Russian name"
  grep -q '^Categories=.*KDE' "$desktop" && fail "$app is filed as a KDE application"
  [[ -s "$package_root/src/apps/$app.cpp" ]] || fail "$app has no host"
done
grep -Fq 'key: "receive"' "$package_root/apps/share/qml/Main.qml" \
  && grep -Fq 'key: "send"' "$package_root/apps/share/qml/Main.qml" \
  || fail "Quick Share has no Receive and Send"
grep -Fq '"org.kernora.quickshare", true}' "$package_root/src/apps/share.cpp" \
  || fail "Quick Share does not reuse its window"
grep -q '^NoDisplay=' "$package_root/apps/share/org.kernora.share.desktop" \
  && fail "Quick Share is hidden from the app menu"
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
assert any('Store' in i['title']['en'] for r in notes for i in r['items'])
assert not any(i['icon'].startswith('org.kernora.') for r in notes for i in r['items'])
for release in notes:
    datetime.date.fromisoformat(release.get('date', release['id'][:10]))
PY

grep -Fq 'readonly property string channelTool: "/usr/libexec/kernora-update-channel"' \
  "$package_root/apps/settings/qml/pages/SystemPage.qml" \
  && grep -Fq 'Process.run("pkexec", [page.channelTool, "set", on ? "demo" : "stable"]' \
  "$package_root/apps/settings/qml/pages/SystemPage.qml" \
  && grep -Fq 'checked: page.channelBusy ? page.channelWanted : page.demo' \
  "$package_root/apps/settings/qml/pages/SystemPage.qml" \
  || fail "Settings cannot turn demo updates on and off"
grep -q kernora-update-channel "$package_root/apps/settings/qml/pages/UpdatesPage.qml" \
  && fail "the demo updates switch is back on the updates page"
grep -Fq 'title: i18n("Early access")' "$package_root/apps/settings/qml/pages/SystemPage.qml" \
  || fail "demo updates are not under Early access in System"
grep -Fq "project(kernora-apps VERSION $version LANGUAGES CXX)" "$package_root/CMakeLists.txt" \
  || fail "the CMake project version is not $version"
grep -Fq 'AppIconSync icons;' "$package_root/src/updatenotifier/main.cpp" \
  && grep -Fq '"/Kernora/scalable/apps"' "$package_root/src/updatenotifier/appiconsync.cpp" \
  && grep -Fq 'readEntry("themedApps", false)' "$package_root/src/updatenotifier/appiconsync.cpp" \
  && grep -Fq 'connect(KSycoca::self(), &KSycoca::databaseChanged' "$package_root/src/updatenotifier/appiconsync.cpp" \
  && grep -Fq 'service->noDisplay()' "$package_root/src/updatenotifier/appiconsync.cpp" \
  && grep -Fq 'info.absolutePath().contains(QLatin1String("/apps"))' "$package_root/src/updatenotifier/appiconsync.cpp" \
  && grep -Fq 'kernora-app-icons --self-test' "$package_root/debian/rules" \
  || fail "app icons are not made the same size and shape"
for file in Main AppsPage ProcessesPage PerformancePage TaskPage UsageCard; do
  [[ -s "$package_root/apps/taskmanager/qml/$file.qml" ]] || fail "Task Manager lacks $file.qml"
done
grep -Fq 'Procs.ApplicationDataModel {' "$package_root/apps/taskmanager/qml/Main.qml" \
  && grep -Fq 'Procs.ProcessDataModel {' "$package_root/apps/taskmanager/qml/ProcessesPage.qml" \
  && grep -Fq 'Files.exists("file:///proc/" + pid)' "$package_root/apps/taskmanager/qml/Main.qml" \
  && grep -Fq 'Procs.ProcessController.KillSignal' "$package_root/apps/taskmanager/qml/Main.qml" \
  && grep -Fq 'sensorId: "gpu/all/totalVram"' "$package_root/apps/taskmanager/qml/PerformancePage.qml" \
  && grep -Fq 'direction: Charts.XYChart.ZeroAtEnd' "$package_root/apps/taskmanager/qml/UsageCard.qml" \
  && grep -Fq 'fillMode: Charts.HistoryProxySource.FillFromStart' "$package_root/apps/taskmanager/qml/UsageCard.qml" \
  && grep -Fq 'return pid > 0 ? [pid] : [];' "$package_root/apps/taskmanager/qml/TaskPage.qml" \
  && grep -Fq 'onClicked: page.sortKey = key' "$package_root/apps/taskmanager/qml/TaskPage.qml" \
  || fail "Task Manager can't list, end or chart"
grep -Fxq 'X-KDE-Shortcuts=Ctrl+Shift+Esc,Ctrl+Esc' "$package_root/apps/taskmanager/org.kernora.taskmanager.desktop" \
  && grep -Fq 'DESTINATION ${KDE_INSTALL_DATADIR}/kglobalaccel' "$package_root/CMakeLists.txt" \
  && grep -q 'share taskmanager)' "$package_root/src/apps/CMakeLists.txt" \
  || fail "Task Manager has no shortcut or is not built"
for dependency in ksystemstats libksysguard-bin qml6-module-org-kde-ksysguard qml6-module-org-kde-kitemmodels qml6-module-org-kde-quickcharts; do
  grep -Eq "^ $dependency,?$" "$package_root/debian/control" || fail "Task Manager needs $dependency"
done
msgfmt --check -o /dev/null "$package_root/po/ru/kernora-taskmanager.po" || fail "the Task Manager translation is broken"
grep -Fq 'key: "themedApps"' "$package_root/apps/settings/qml/pages/AppearancePage.qml" \
  && grep -Fq 'msgid "Themed app icons"' "$package_root/po/ru/kernora-settings.po" \
  && grep -Eq '^ qt6-svg-plugins,$' "$package_root/debian/control" \
  || fail "themed app icons cannot be turned on"
grep -Eq '^ kernora-archive \(>= 1\.2\),$' "$package_root/debian/control" \
  || fail "kernora-apps does not require the kernora-archive with demo updates"
grep -Fq 'msgid "Demo updates"' "$package_root/po/ru/kernora-settings.po" \
  || fail "the demo updates switch is not translated"

grep -Fq 'void Files::setLockScreenPlugin' "$package_root/src/system/files.cpp" \
  && grep -Fq 'Files.syncGreeterBackground' "$package_root/apps/settings/qml/pages/AppearancePage.qml" \
  || fail "live wallpapers cannot reach the lock and login screens"

grep -Fq 'GreeterSync greeter;' "$package_root/src/updatenotifier/main.cpp" \
  && grep -Fq '/usr/libexec/kernora-greeter-background' "$package_root/src/updatenotifier/greetersync.cpp" \
  && grep -Fq 'plasma-org.kde.plasma.desktop-appletsrc' "$package_root/src/updatenotifier/greetersync.cpp" \
  || fail "the login screen does not follow wallpapers chosen outside Settings"

grep -Fq 'AvatarSync avatar;' "$package_root/src/updatenotifier/main.cpp" \
  && grep -Fq 'kernora/faces/%1.png' "$package_root/src/updatenotifier/avatarsync.cpp" \
  && grep -Fq 'kernora/faces/%1.png' "$package_root/src/system/accounts.cpp" \
  || fail "the Kernora avatar does not follow the colour"
grep -Fq 'wallpaper.colour, wallpaper.mode' "$package_root/src/updatenotifier/greetersync.cpp" \
  || fail "the login screen does not get the colour and theme"
grep -Fq '"/kdedefaults/kdeglobals"' "$package_root/src/updatenotifier/greetersync.cpp" \
  || fail "the login screen turns dark after plasma moves the colour scheme to kdedefaults"

grep -Fq 'MLoadingIndicator {' "$package_root/apps/store/qml/AppPage.qml" \
  || fail "screenshots in Store do not use the loading indicator"
grep -Fq 'component BusyIndicatorOverlay: MLoadingIndicator {' "$package_root/apps/photos/qml/Main.qml" \
  || fail "the photo viewer does not use the loading indicator"
grep -Fq '.filter(m => !internal.includes(m.id) && catalog.resolve(m.id) === null)' "$package_root/apps/settings/qml/pages/ModulesPage.qml" \
  && grep -Fq '"kcm_activities"' "$package_root/apps/settings/qml/pages/ModulesPage.qml" \
  || fail "More settings still lists KDE modules Kernora replaces"
grep -Fq "writeConfig('IntroAt', String(Date.now()));" "$package_root/src/system/files.cpp" \
  || fail "switching a live wallpaper does not mark it for its intro"
grep -Fq 'id: selectionBar' "$package_root/apps/files/qml/Main.qml" \
  && grep -Fq 'active: !fab.collapsed || M3.classic' "$package_root/apps/files/qml/Main.qml" \
  || fail "Files has no selection toolbar or collapsing button"
grep -Fq 'FloatingToolbar {' "$package_root/apps/photos/qml/Main.qml" \
  && grep -Fq 'shown: chrome.shown' "$package_root/apps/photos/qml/Main.qml" \
  || fail "the photo viewer has no floating toolbar"
for file in apps/calculator/qml/Main.qml apps/player/qml/Main.qml apps/photos/qml/Main.qml apps/screenshot/qml/Main.qml \
    apps/welcome/qml/Main.qml apps/settings/qml/components/WallpaperTile.qml; do
  ! grep -Fq 'Behavior on radius' "$package_root/$file" && grep -Fq 'MMorph {' "$package_root/$file" \
    || fail "$file still changes shape on a plain curve"
done
! grep -qi 'ocean' "$package_root/apps/settings/qml/pages/SoundPage.qml" \
  || fail "Settings still offers the KDE sound theme"
grep -Fq 'onClosing: retire()' "$package_root/apps/welcome/qml/Main.qml" \
  && grep -Fq 'Config.write(entry, "Desktop Entry", "NoDisplay", true);' "$package_root/apps/welcome/qml/Main.qml" \
  || fail "welcome does not leave after its first showing"
grep -Fq 'readonly property string versionText: SystemInfo.osVersion' "$package_root/apps/settings/qml/pages/AboutPage.qml" \
  || fail "About still glues the codename onto the version"
grep -Fq 'indeterminate: Updates.progress <= 0 || Updates.progress >= 100' "$package_root/apps/settings/qml/pages/UpdatesPage.qml" \
  || fail "the update bar flashes full while packagekit reports 100%"

printf 'kernora-apps source test: OK\n'
