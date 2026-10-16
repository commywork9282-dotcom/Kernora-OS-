#!/usr/bin/env bash
set -Eeuo pipefail

project_root=$(CDPATH= cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)
package_root="$project_root/packages/native/kernora-desktop"
package_version=$(dpkg-parsechangelog -l"$package_root/debian/changelog" -S Version)
binary_dir="$project_root/_build/binary-packages"
desktop_deb="$binary_dir/kernora-desktop_${package_version}_all.deb"
installer_deb="$binary_dir/kernora-calamares_${package_version}_all.deb"

fail() {
  printf 'kernora-desktop binary test: %s\n' "$*" >&2
  exit 1
}

for dependency in dpkg-deb find grep mktemp; do
  command -v "$dependency" >/dev/null 2>&1 \
    || fail "required command not found: $dependency"
done

for deb in "$desktop_deb" "$installer_deb"; do
  [[ -s "$deb" ]] || fail "binary package does not exist: $deb"
  [[ "$(dpkg-deb --field "$deb" Version)" == "$package_version" ]] \
    || fail "wrong package version in $deb"
  [[ "$(dpkg-deb --field "$deb" Architecture)" == "all" ]] \
    || fail "wrong package architecture in $deb"
done
[[ "$(dpkg-deb --field "$desktop_deb" Package)" == "kernora-desktop" ]] \
  || fail "wrong desktop package name"
[[ "$(dpkg-deb --field "$installer_deb" Package)" == "kernora-calamares" ]] \
  || fail "wrong installer package name"
dpkg-deb --field "$installer_deb" Depends | grep -Fq calamares \
  || fail "installer configuration does not depend on calamares"

temporary_root=$(mktemp -d /tmp/kernora-desktop-test.XXXXXX)
trap 'find "$temporary_root" -depth -delete' EXIT
dpkg-deb --extract "$desktop_deb" "$temporary_root/desktop"
dpkg-deb --extract "$installer_deb" "$temporary_root/installer"

for path in \
  etc/dpkg/dpkg.cfg.d/kernora-wallpapers \
  usr/share/icons/kernora_cursors/index.theme \
  usr/share/icons/kernora_cursors/cursor.theme \
  usr/share/icons/kernora_cursors/cursors/default \
  usr/share/icons/kernora_cursors/cursors/wait \
  usr/share/icons/kernora_cursors/cursors/progress \
  usr/share/icons/kernora_cursors/cursors_scalable/wait/metadata.json \
  etc/xdg/kcminputrc \
  etc/xdg/klaunchrc \
  usr/share/plasma/look-and-feel/org.kernora.desktop/metadata.json \
  usr/share/plasma/look-and-feel/org.kernora.desktop/contents/defaults \
  etc/xdg/kdeglobals \
  usr/share/icons/hicolor/scalable/apps/kernora-logo.svg \
  usr/share/icons/hicolor/48x48/apps/kernora-logo.png \
  usr/share/icons/hicolor/256x256/apps/kernora-logo.png \
  etc/skel/.face \
  etc/skel/.local/share/applications/org.kde.plasma.emojier.desktop \
  etc/skel/.local/share/applications/org.kde.drkonqi.coredump.gui.desktop \
  usr/share/plasma/look-and-feel/org.kernora.desktop/contents/plasmoidsetupscripts/org.kde.plasma.kickoff.js \
  usr/share/plasma/look-and-feel/org.kernora.desktop/contents/plasmoidsetupscripts/org.kde.plasma.icontasks.js \
  usr/share/icons/Kernora/index.theme \
  usr/share/icons/Kernora/scalable/apps/start-here-kde-symbolic.svg \
  usr/share/icons/Kernora/scalable/apps/start-here-kde.svg \
  usr/share/plasma/look-and-feel/org.kernora.desktop/contents/splash/Splash.qml \
  usr/share/plasma/look-and-feel/org.kernora.desktop/contents/splash/images/kernora.png \
  usr/share/plasma/look-and-feel/org.kernora.desktop/contents/layouts/org.kde.plasma.desktop-layout.js \
  etc/xdg/plasmarc \
  usr/share/color-schemes/KernoraDark.colors \
  usr/share/color-schemes/KernoraLight.colors \
  usr/share/plasma/desktoptheme/kernora/metadata.json \
  usr/share/plasma/desktoptheme/kernora/colors \
  usr/share/plasma/desktoptheme/kernora/widgets/panel-background.svg \
  usr/share/plasma/desktoptheme/kernora/dialogs/background.svg \
  usr/share/plasma/desktoptheme/kernora/widgets/tasks.svg \
  usr/share/plasma/desktoptheme/kernora/widgets/slider.svg \
  usr/share/plasma/desktoptheme/kernora/icons/audio.svg \
  usr/share/icons/Kernora/scalable/status/audio-volume-high.svg \
  usr/share/icons/Kernora/scalable/status/audio-volume-high-symbolic.svg \
  usr/share/icons/Kernora/scalable/actions/system-shutdown.svg \
  usr/share/locale/ru/LC_MESSAGES/plasma_applet_org.kernora.launcher.mo \
  usr/share/locale/ru/LC_MESSAGES/plasma_applet_org.kernora.quicksettings.mo \
  usr/share/locale/ru/LC_MESSAGES/plasma_applet_org.kernora.clipboard.mo \
  etc/xdg/klipperrc \
  etc/skel/.config/kglobalshortcutsrc \
  usr/share/knotifications6/kernora-devices.notifyrc \
  usr/share/plasma/plasmoids/org.kernora.quicksettings/contents/ui/sources/DeviceSource.qml \
  usr/share/plasma/plasmoids/org.kernora.quicksettings/contents/ui/sources/ThemeSource.qml \
  usr/share/plasma/desktoptheme/kernora-md1/metadata.json \
  usr/share/plasma/desktoptheme/kernora-md1-light/colors \
  usr/share/plasma/desktoptheme/kernora-md2/dialogs/background.svg \
  usr/share/plasma/desktoptheme/kernora-md2-light/metadata.json \
  usr/share/color-schemes/KernoraMD1Dark.colors \
  usr/share/color-schemes/KernoraMD1Light.colors \
  usr/share/color-schemes/KernoraMD2Dark.colors \
  usr/share/color-schemes/KernoraMD2Light.colors \
  usr/share/Kvantum/KernoraMD1/KernoraMD1Dark.kvconfig \
  usr/share/Kvantum/KernoraMD2/KernoraMD2.svg \
  usr/share/aurorae/themes/kernora-md1/decoration.svg \
  usr/share/aurorae/themes/kernora-md2-light/kernora-md2-lightrc \
  usr/share/plasma/wallpapers/org.kernora.shapes/metadata.json \
  usr/share/plasma/wallpapers/org.kernora.shapes/contents/ui/main.qml \
  usr/share/plasma/wallpapers/org.kernora.shapes/contents/ui/materialshapes.js \
  usr/share/plasma/wallpapers/org.kernora.shapes/contents/ui/palettes/kernora.qml \
  usr/share/plasma/wallpapers/org.kernora.shapes/contents/ui/palettes/blue-grey.qml \
  usr/share/plasma/wallpapers/org.kernora.rhythm/metadata.json \
  usr/share/plasma/wallpapers/org.kernora.rhythm/contents/ui/Scene.qml \
  usr/share/plasma/wallpapers/org.kernora.rhythm/contents/ui/palettes/kernora.qml \
  usr/share/plasma/wallpapers/org.kernora.rhythm/contents/ui/palettes/blue-grey.qml \
  usr/share/plasma/wallpapers/org.kernora.pastel/metadata.json \
  usr/share/plasma/wallpapers/org.kernora.starfall/metadata.json \
  usr/share/plasma/wallpapers/org.kernora.starfall/contents/ui/Scene.qml \
  usr/share/plasma/wallpapers/org.kernora.starfall/contents/ui/materialshapes.js \
  usr/share/plasma/wallpapers/org.kernora.starfall/contents/ui/palettes/kernora.qml \
  usr/share/plasma/wallpapers/org.kernora.starfall/contents/ui/palettes/blue-grey.qml \
  usr/share/locale/ru/LC_MESSAGES/plasma_wallpaper_org.kernora.starfall.mo \
  usr/share/plasma/wallpapers/org.kernora.pastel/contents/ui/Scene.qml \
  usr/share/plasma/wallpapers/org.kernora.pastel/contents/ui/materialshapes.js \
  usr/share/kconf_update/kernora-marbles-to-pastel.upd \
  usr/share/plasma/shells/org.kde.plasma.desktop/contents/updates/kernora_marbles_to_pastel.js \
  usr/share/kconf_update/kernora-tower-to-shapes.upd \
  usr/share/kconf_update/kernora-tower-to-shapes.sh \
  usr/share/plasma/shells/org.kde.plasma.desktop/contents/updates/kernora_tower_to_shapes.js \
  usr/share/plasma/wallpapers/org.kernora.pastel/contents/ui/palettes/kernora.qml \
  usr/share/plasma/wallpapers/org.kernora.pastel/contents/ui/palettes/blue-grey.qml \
  usr/share/locale/ru/LC_MESSAGES/plasma_wallpaper_org.kernora.pastel.mo \
  usr/share/Kvantum/Kernora/Kernora.kvconfig \
  usr/share/Kvantum/Kernora/Kernora.svg \
  usr/share/Kvantum/Kernora/KernoraDark.kvconfig \
  usr/share/Kvantum/Kernora/KernoraDark.svg \
  etc/xdg/Kvantum/kvantum.kvconfig \
  usr/share/aurorae/themes/kernora/metadata.desktop \
  usr/share/aurorae/themes/kernora/kernorarc \
  usr/share/aurorae/themes/kernora/decoration.svg \
  usr/share/aurorae/themes/kernora/close.svg \
  usr/share/aurorae/themes/kernora/maximize.svg \
  usr/share/aurorae/themes/kernora/minimize.svg \
  usr/share/aurorae/themes/kernora/restore.svg \
  usr/share/aurorae/themes/kernora-light/kernora-lightrc \
  usr/share/aurorae/themes/kernora-light/decoration.svg \
  usr/lib/x86_64-linux-gnu/qt6/qml/org/kernora/desktop/qmldir \
  usr/lib/x86_64-linux-gnu/qt6/qml/org/kernora/desktop/Button.qml \
  usr/lib/x86_64-linux-gnu/qt6/qml/org/kernora/desktop/Menu.qml \
  usr/lib/x86_64-linux-gnu/qt6/qml/org/kernora/desktop/private/SwitchIndicator.qml \
  usr/lib/x86_64-linux-gnu/qt6/qml/org/kernora/desktop/impl/qmldir \
  usr/lib/x86_64-linux-gnu/qt6/qml/org/kernora/m3/qmldir \
  usr/lib/x86_64-linux-gnu/qt6/qml/org/kernora/m3/M3.qml \
  usr/lib/x86_64-linux-gnu/qt6/qml/org/kernora/ui/qmldir \
  usr/lib/x86_64-linux-gnu/qt6/qml/org/kernora/ui/ListItem.qml \
  usr/lib/x86_64-linux-gnu/qt6/qml/org/kernora/ui/Page.qml \
  usr/share/locale/ru/LC_MESSAGES/kernora-ui.mo \
  usr/lib/x86_64-linux-gnu/qt6/qml/org/kernora/desktop/impl/M3.qml \
  etc/xdg/plasma-workspace/env/kernora-qtquick-style.sh \
  etc/xdg/kwinrc \
  etc/skel/.local/share/applications/kvantummanager.desktop \
  usr/share/icons/Kernora/scalable/apps/preferences-system.svg \
  usr/share/icons/Kernora/scalable/categories/preferences-desktop-effects.svg; do
  [[ -s "$temporary_root/desktop/$path" ]] \
    || fail "desktop package is missing $path"
done

for id in org.kernora.launcher org.kernora.quicksettings org.kernora.clipboard; do
  applet="$temporary_root/desktop/usr/share/plasma/plasmoids/$id"
  for path in metadata.json contents/ui/main.qml contents/ui/m3/qmldir \
    contents/ui/m3/M3.qml contents/ui/m3/MSlider.qml contents/ui/m3/MTile.qml; do
    [[ -s "$applet/$path" ]] || fail "applet $id is missing $path"
  done
  grep -Fq 'pragma Singleton' "$applet/contents/ui/m3/M3.qml" \
    || fail "applet $id carries no design-token singleton"
  if grep -Eq 'property color on[A-Z]' "$applet/contents/ui/m3/M3.qml"; then
    fail "applet $id tokens declare an on* colour property"
  fi
done
[[ -s "$temporary_root/desktop/usr/share/plasma/plasmoids/org.kernora.launcher/contents/config/main.xml" ]] \
  || fail "launcher has no configuration schema"

kdeglobals="$temporary_root/desktop/etc/xdg/kdeglobals"
grep -Fxq 'LookAndFeelPackage=org.kernora.desktop' "$kdeglobals" \
  || fail "Kernora look-and-feel is not the system default"
grep -Fxq 'ColorScheme=KernoraDark' "$kdeglobals" \
  || fail "system defaults do not carry the Kernora colour scheme"
grep -Fxq '[Colors:Window]' "$kdeglobals" \
  || fail "system defaults do not carry the colour scheme's colours"
grep -Fxq 'Theme=Kernora' "$kdeglobals" \
  || fail "system defaults do not select the Kernora icon theme"
grep -Fxq 'name=kernora' "$temporary_root/desktop/etc/xdg/plasmarc" \
  || fail "system defaults do not select the Kernora Plasma theme"
grep -Fq 'Inherits=breeze-dark' "$temporary_root/desktop/usr/share/icons/Kernora/index.theme" \
  || fail "icon theme does not inherit Breeze"
[[ -L "$temporary_root/desktop/usr/share/icons/Kernora/scalable/status/audio-volume-high-symbolic.svg" ]] \
  || fail "icon aliases are not symlinks"
platform="$temporary_root/desktop/usr/lib/x86_64-linux-gnu/qt6/plugins/kf6/kirigami/platform"
[[ "$(readlink "$platform/org.kernora.desktop.so")" == "org.kde.desktop.so" ]] \
  || fail "Kirigami platform plugin link does not lead to the desktop plugin"
[[ "$(readlink "$temporary_root/desktop/etc/skel/.face.icon")" == ".face" ]] \
  || fail "the shell does not see the default profile picture"
grep -Fxq 'widgetStyle=kvantum-dark' "$kdeglobals" \
  || fail "system defaults do not select the Kvantum widget style"
if grep -q '^AccentColor=' "$temporary_root/desktop/usr/share/color-schemes/KernoraDark.colors"; then
  fail "colour scheme carries an accent colour KDE would blend into selections"
fi
grep -Fq 'pragma Singleton' \
  "$temporary_root/desktop/usr/lib/x86_64-linux-gnu/qt6/qml/org/kernora/desktop/impl/M3.qml" \
  || fail "Qt Quick style carries no design-token singleton"
for field in fonts-roboto-unhinted plasma-workspace qt-style-kvantum kwin-common \
  qml6-module-org-kde-desktop qml6-module-qtquick-shapes; do
  dpkg-deb --field "$desktop_deb" Depends | grep -Fq "$field" \
    || fail "desktop package does not depend on $field"
done

for path in \
  etc/calamares/settings.conf \
  etc/calamares/modules/unpackfs.conf \
  etc/calamares/modules/removeuser.conf \
  etc/calamares/modules/shellprocess-drivers.conf \
  etc/calamares/branding/kernora/branding.desc \
  etc/calamares/branding/kernora/show.qml \
  etc/calamares/branding/kernora/kernora-logo.png \
  etc/calamares/branding/kernora/kernora-welcome.png \
  etc/calamares/branding/kernora/calamares-sidebar.qml \
  etc/calamares/branding/kernora/calamares-navigation.qml \
  etc/calamares/branding/kernora/welcomeq.qml \
  etc/calamares/branding/kernora/localeq.qml \
  etc/calamares/branding/kernora/keyboardq.qml \
  etc/calamares/branding/kernora/keymaps.js \
  etc/calamares/branding/kernora/lang/calamares-kernora_ru.qm \
  etc/calamares/branding/kernora/stylesheet.qss \
  etc/calamares/branding/kernora/images/partition-erase-auto.svg \
  etc/calamares/branding/kernora/usersq.qml \
  etc/calamares/branding/kernora/summaryq.qml \
  etc/calamares/branding/kernora/finishedq.qml \
  etc/calamares/modules/usersq.conf \
  etc/calamares/modules/finishedq.conf \
  usr/bin/kernora-installer \
  usr/share/polkit-1/actions/org.kernora.installer.policy \
  usr/share/polkit-1/rules.d/49-kernora-installer.rules \
  usr/share/applications/org.kernora.installer.desktop; do
  [[ -s "$temporary_root/installer/$path" ]] \
    || fail "installer package is missing $path"
done
dpkg-deb --field "$installer_deb" Depends | grep -Fq pkexec \
  || fail "installer package does not depend on pkexec, which starts Calamares"

for path in \
  etc/alacritty/alacritty.toml \
  usr/share/kernora/terminal/dark.toml \
  usr/share/kernora/terminal/light.toml \
  usr/share/applications/org.kernora.terminal.desktop \
  usr/share/plasma/desktoptheme/kernora-light/metadata.json \
  usr/share/plasma/desktoptheme/kernora-light/colors \
  usr/share/icons/Kernora/scalable/apps/org.kernora.settings.svg \
  usr/share/icons/Kernora/scalable/apps/org.kernora.files.svg \
  usr/share/sddm/themes/kernora/Main.qml \
  usr/share/sddm/themes/kernora/metadata.desktop \
  usr/share/sddm/themes/kernora/palette.js \
  usr/share/sddm/themes/kernora/icons/login.svg; do
  [[ -e "$temporary_root/desktop/$path" ]] \
    || fail "desktop package is missing $path"
done

shell=usr/share/plasma/shells/org.kde.plasma.desktop/contents
notifications=usr/share/plasma/plasmoids/org.kde.plasma.notifications/contents/ui
for path in \
  "$shell/lockscreen/LockScreen.qml" \
  "$shell/lockscreen/KernoraMediaControls.qml" \
  "$shell/osd/Osd.qml" \
  "$shell/osd/KernoraOsdItem.qml" \
  "$shell/configuration/AppletConfiguration.qml" \
  "$shell/configuration/ConfigurationContainmentAppearance.qml" \
  "$shell/configuration/ConfigurationContainmentActions.qml" \
  "$shell/configuration/AboutPlugin.qml" \
  "$shell/configuration/ConfigurationShortcuts.qml" \
  usr/share/plasma/plasmoids/org.kde.desktopcontainment/contents/ui/ConfigLocation.qml \
  usr/share/plasma/plasmoids/org.kde.desktopcontainment/contents/ui/ConfigIcons.qml \
  usr/share/plasma/plasmoids/org.kde.desktopcontainment/contents/ui/ConfigFilter.qml \
  usr/share/plasma/plasmoids/org.kde.desktopcontainment/contents/ui/ConfigOverlay.qml \
  usr/share/plasma/plasmoids/org.kde.plasma.panelspacer/contents/ui/main.qml \
  "$shell/explorer/WidgetExplorer.qml" \
  "$shell/explorer/WidgetPreview.qml" \
  "$shell/explorer/WidgetDrag.qml" \
  "$shell/explorer/MaterialShape.qml" \
  "$shell/explorer/materialshapes.js" \
  "$shell/views/DesktopEditMode.qml" \
  "$shell/configuration/panelconfiguration/PanelRepresentation.qml" \
  "$notifications/main.qml" \
  "$notifications/kernora/global/Globals.qml" \
  "$notifications/kernora/global/qmldir" \
  "$notifications/kernora/NotificationPopup.qml" \
  "$notifications/kernora/FullRepresentation.qml" \
  "$notifications/kernora/CompactRepresentation.qml" \
  "$notifications/kernora/delegates/DelegatePopup.qml" \
  "$notifications/kernora/components/AppBadge.qml" \
  usr/share/locale/ru/LC_MESSAGES/kernora-notifications.mo \
  usr/share/plasma/plasmoids/org.kde.plasma.taskmanager/contents/ui/Badge.qml \
  usr/share/plasma/plasmoids/org.kde.plasma.taskmanager/contents/ui/ToolTipInstance.qml \
  usr/share/plymouth/themes/kernora/kernora.plymouth \
  usr/share/plymouth/themes/kernora/kernora.script \
  usr/share/plymouth/themes/kernora/logo.png \
  usr/share/plymouth/themes/kernora/shape-6.png \
  usr/share/plymouth/themes/kernora/entry.png \
  usr/share/plymouth/plymouthd.defaults \
  etc/default/grub.d/kernora.cfg \
  usr/lib/systemd/system/plymouth-quit.service.d/plymouth-quit-kernora.conf \
  usr/lib/systemd/system/sddm.service.d/sddm-plymouth.conf \
  usr/share/grub/themes/kernora/theme.txt \
  usr/share/grub/themes/kernora/logo.png \
  usr/share/grub/themes/kernora/select_nw.png \
  usr/share/grub/themes/kernora/roboto-regular-16.pf2 \
  usr/share/grub/themes/kernora/roboto-medium-16.pf2 \
  usr/share/grub/themes/kernora/roboto-regular-24.pf2 \
  usr/share/plasma/look-and-feel/org.kernora.desktop/contents/logout/Logout.qml \
  usr/share/plasma/look-and-feel/org.kernora.desktop/contents/logout/timer.js \
  usr/share/kwin/tabbox/org.kernora.switcher/metadata.json \
  usr/share/kwin/tabbox/org.kernora.switcher/contents/ui/main.qml \
  usr/share/themes/Kernora/gtk-3.0/gtk.css \
  usr/share/themes/Kernora/gtk-3.0/gtk-dark.css \
  usr/share/themes/Kernora/gtk-4.0/gtk.css \
  usr/share/themes/KernoraMD1/gtk-3.0/gtk.css \
  usr/share/themes/KernoraMD2/gtk-3.0/gtk.css \
  usr/share/glib-2.0/schemas/90_kernora.gschema.override \
  usr/share/kconf_update/kernora-gtk-theme.upd \
  usr/share/kconf_update/kernora-gtk-theme.sh \
  etc/skel/.config/gtk-3.0/settings.ini \
  usr/share/librewolf/distribution/extensions/theme@kernora.os.xpi \
  usr/share/librewolf/browser/defaults/preferences/kernora.js \
  usr/share/kernora/librewolf/userChrome.css \
  usr/share/kconf_update/kernora-librewolf-chrome.upd \
  usr/share/kconf_update/kernora-librewolf-chrome.sh \
  usr/share/sounds/kernora/index.theme \
  usr/share/kernora/avatars/00-kernora.png \
  usr/share/kernora/avatars/01-ember-layers.png \
  usr/share/sounds/kernora/stereo/desktop-login.wav \
  usr/share/sounds/kernora/stereo/dialog-information.wav \
  usr/share/sounds/kernora/stereo/bell-window-system.wav \
  usr/share/kconf_update/kernora-sound-theme.upd \
  usr/share/kconf_update/kernora-sound-theme.sh \
  usr/share/kconf_update/kernora-terminal-entry.upd \
  usr/share/kconf_update/kernora-terminal-entry.sh \
  etc/xdg/plasma_workspace.notifyrc \
  usr/libexec/kernora-crash-notifier \
  usr/lib/systemd/user/drkonqi-coredump-launcher@.service.d/drkonqi-coredump-launcher-kernora.conf \
  etc/xdg/mimeapps.list; do
  [[ -e "$temporary_root/desktop/$path" ]] \
    || fail "desktop package is missing $path"
done
grep -Fxq 'LayoutName=org.kernora.switcher' "$temporary_root/desktop/etc/xdg/kwinrc" \
  || fail "Alt+Tab does not use the Kernora window switcher"
grep -Fxq 'Theme=kernora' "$temporary_root/desktop/usr/share/plymouth/plymouthd.defaults" \
  || fail "Plymouth does not default to the Kernora boot splash"
find "$temporary_root/desktop/usr/share/plymouth/themes/kernora" -name '*.svg' | grep -q . \
  && fail "the boot splash still carries SVGs Plymouth cannot read"
grep -Fxq 'X-KDE-Shortcuts=Alt+F2,Search' "$temporary_root/desktop/usr/share/kglobalaccel/org.kde.krunner.desktop" \
  || fail "KRunner still takes Alt+Space from the Kernora launcher"
grep -Fq 'launcher.globalShortcut = "Alt+Space"' \
  "$temporary_root/desktop/usr/share/plasma/look-and-feel/org.kernora.desktop/contents/layouts/org.kde.plasma.desktop-layout.js" \
  || fail "the Kernora launcher does not open with Alt+Space"
grep -Fxq 'X-KDE-Shortcuts=Ctrl+Alt+T' "$temporary_root/desktop/usr/share/applications/org.kernora.terminal.desktop" \
  || fail "Ctrl+Alt+T does not open the terminal"
[[ "$(find "$temporary_root/desktop/usr/share/kernora/avatars" -name '*.png' | wc -l)" -eq 15 ]] \
  || fail "the Kernora profile pictures are missing"
[[ "$(find "$temporary_root/desktop/usr/share/kernora/palettes" -name '*.conf' | wc -l)" -eq 20 ]] \
  || fail "the colour palettes are not twenty"
for path in \
  usr/share/color-schemes/KernoraDeepPurpleMD1Light.colors \
  usr/share/color-schemes/KernoraBlueDark.colors \
  usr/share/Kvantum/KernoraBlue/KernoraBlue.kvconfig \
  usr/share/Kvantum/KernoraBlueGreyMD2/KernoraBlueGreyMD2Dark.svg \
  usr/share/aurorae/themes/kernora-blue-md1-light/decoration.svg \
  usr/share/themes/KernoraTeal/gtk-3.0/gtk.css \
  usr/share/kernora/terminal/blue/dark.toml \
  usr/share/icons/Kernora-blue/index.theme \
  usr/share/icons/Kernora-blue/scalable/apps/org.kernora.files.svg \
  usr/share/plasma/desktoptheme/kernora-blue/colors \
  usr/share/plasma/desktoptheme/kernora-blue-md1-light/widgets/panel-background.svg; do
  [[ -e "$temporary_root/desktop/$path" ]] || fail "a colour theme is incomplete: $path"
done
[[ -L "$temporary_root/desktop/usr/share/plasma/desktoptheme/kernora-red/widgets" ]] \
  || fail "the red Plasma theme copies its pictures instead of linking them"
[[ -s "$temporary_root/desktop/usr/lib/sysctl.d/90-kernora-panic.conf" ]] || fail "the panic timeout is missing"
[[ -x "$temporary_root/desktop/usr/libexec/kernora-panic-report" ]] || fail "the panic report is missing"
grep -Fxq 'After=systemd-pstore.service' "$temporary_root/desktop/usr/lib/systemd/system/kernora-panic-report.service" \
  || fail "the panic report does not wait for systemd-pstore"
dpkg-deb --ctrl-tarfile "$desktop_deb" | tar -xO ./postinst 2>/dev/null | grep -q 'kernora-panic-report.service' \
  || fail "the panic report service is not enabled on installation"
[[ -x "$temporary_root/desktop/usr/libexec/kernora-drivers" ]] \
  && [[ -s "$temporary_root/desktop/usr/share/kernora/nvidia-archive-keyring.gpg" ]] \
  && [[ -s "$temporary_root/desktop/usr/lib/systemd/system/kernora-drivers@.service" ]] \
  && [[ -s "$temporary_root/desktop/usr/share/polkit-1/actions/org.kernora.drivers.policy" ]] \
  || fail "the graphics driver tool is incomplete"
dpkg-deb --ctrl-tarfile "$desktop_deb" | tar -xO ./postinst 2>/dev/null | grep -q 'kernora-drivers.timer' \
  || fail "the graphics driver check is not enabled on installation"
dpkg-deb --ctrl-tarfile "$desktop_deb" | tar -xO ./postinst 2>/dev/null | grep -q "'kernora-drivers.service'" \
  && fail "installing the package would run the driver install inside the dpkg transaction"
[[ "$(readlink "$temporary_root/desktop/usr/share/kglobalaccel/org.kernora.terminal.desktop")" == */applications/org.kernora.terminal.desktop ]] \
  || fail "kglobalaccel does not see the terminal's launch shortcut"
grep -Fxq 'Icon=org.kernora.terminal' "$temporary_root/desktop/etc/skel/.local/share/applications/Alacritty.desktop" \
  || fail "a terminal started without its class shows the Wayland icon"
grep -Fq 'clipboard.globalShortcut = "Meta+V"' \
  "$temporary_root/desktop/usr/share/plasma/look-and-feel/org.kernora.desktop/contents/layouts/org.kde.plasma.desktop-layout.js" \
  || fail "the Kernora clipboard does not open with Meta+V"
grep -Fxq 'show-on-mouse-pos=none,Meta+V,Show Clipboard Items at Mouse Position' \
  "$temporary_root/desktop/etc/skel/.config/kglobalshortcutsrc" \
  || fail "Klipper's own popup still takes Meta+V from the Kernora clipboard"
grep -Fxq 'IgnoreImages=false' "$temporary_root/desktop/etc/xdg/klipperrc" \
  || fail "the clipboard history leaves pictures out"
grep -Fxq 'DesktopEntry=org.kernora.files' "$temporary_root/desktop/usr/share/knotifications6/kernora-devices.notifyrc" \
  || fail "storage notifications do not come from Files"
m3_tokens="$temporary_root/desktop/usr/lib/x86_64-linux-gnu/qt6/qml/org/kernora/m3/M3.qml"
grep -Fq 'property string generation: "md3"' "$m3_tokens" && grep -Fq '/kernorarc' "$m3_tokens" \
  && grep -Fq 'md1: { dark:' "$m3_tokens" && grep -Fq 'md2: { dark:' "$m3_tokens" \
  || fail "the design tokens do not carry the Material generations"
grep -Fxq 'ColorScheme=KernoraMD2Dark' "$temporary_root/desktop/usr/share/color-schemes/KernoraMD2Dark.colors" \
  || fail "the Material Design 2 colour scheme is misnamed"
shade_sheet="$temporary_root/desktop/usr/share/plasma/plasmoids/org.kernora.quicksettings/contents/ui/ShadeSheet.qml"
grep -Fq 'i18n("Dark Theme")' "$shade_sheet" && grep -Fq 'i18n("Screenshot")' "$shade_sheet" \
  || fail "quick settings lack the Dark Theme and Screenshot tiles"
grep -Fxq 'X-KDE-Shortcuts=Meta+Ctrl+Alt+Shift+Space' "$temporary_root/desktop/usr/share/kglobalaccel/org.kde.plasma.emojier.desktop" \
  || fail "the emoji selector still takes Meta+. from the Kernora emoji tab"
grep -Fq 'emoji.globalShortcut = "Meta+."' \
  "$temporary_root/desktop/usr/share/plasma/look-and-feel/org.kernora.desktop/contents/layouts/org.kde.plasma.desktop-layout.js" \
  || fail "the Kernora emoji tab does not open with Meta+."
for widget in clock glance weather battery calendar media photo note; do
  widget_root="$temporary_root/desktop/usr/share/plasma/plasmoids/org.kernora.widget.$widget"
  for path in metadata.json contents/ui/main.qml contents/ui/m3/M3.qml contents/ui/materialshapes.js \
      contents/ui/MaterialShape.qml contents/config/main.xml; do
    [[ -s "$widget_root/$path" ]] || fail "the $widget widget lacks $path"
  done
  python3 -c 'import json,sys; m=json.load(open(sys.argv[1]))["KPlugin"]; assert m["Name[ru]"] and m["Description[ru]"]' \
    "$widget_root/metadata.json" || fail "the $widget widget has no Russian name"
  grep -q 'name="placed"' "$widget_root/contents/config/main.xml" \
    || fail "the $widget widget does not remember that it was placed"
done
for widget in glance weather; do
  [[ -s "$temporary_root/desktop/usr/share/locale/ru/LC_MESSAGES/plasma_applet_org.kernora.widget.$widget.mo" ]] \
    || fail "the $widget widget is not translated"
  [[ -s "$temporary_root/desktop/usr/share/plasma/plasmoids/org.kernora.widget.$widget/contents/ui/WeatherModel.qml" ]] \
    || fail "the $widget widget has no weather source"
done
[[ -s "$temporary_root/desktop/usr/share/plasma/plasmoids/org.kernora.widget.glance/contents/ui/BatterySource.qml" ]] \
  || fail "At a Glance has no battery source"
[[ -s "$temporary_root/desktop/usr/share/plasma/plasmoids/org.kernora.widget.media/contents/ui/MediaSource.qml" ]] \
  || fail "the Now Playing widget has no media source"
grep -Fxq 'Script=kernora-add-widgets-menu.sh,sh' "$temporary_root/desktop/usr/share/kconf_update/kernora-add-widgets-menu.upd" \
  || fail "the desktop menu migration is not installed"
grep -Fxq 'ExecStartPre=-/usr/share/kconf_update/kernora-add-widgets-menu.sh' \
  "$temporary_root/desktop/usr/lib/systemd/user/plasma-plasmashell.service.d/kernora-widgets-menu.conf" \
  || fail "the desktop menu lacks Add Widgets until plasmashell restarts"
grep -Fq 'text/x-plasmoidservicename' "$temporary_root/desktop/$shell/explorer/WidgetDrag.qml" \
  || fail "widgets cannot be dragged from the Kernora widget picker"
grep -Fq 'onShouldClose: main.closed()' "$temporary_root/desktop/$shell/explorer/WidgetExplorer.qml" \
  || fail "the Kernora widget picker does not keep Plasma's explorer contract"
[[ -s "$temporary_root/desktop/usr/share/plasma/desktoptheme/kernora/widgets/margins-highlight.svg" ]] \
  || fail "the Plasma theme lets edit mode fall back to Breeze's margin highlight"
grep -Fq 'allowDmaBuf: false' "$temporary_root/desktop/usr/share/plasma/plasmoids/org.kde.plasma.taskmanager/contents/ui/KernoraWindowThumbnail.qml" \
  || fail "window previews may arrive garbled over DMA-BUF"
grep -Fq 'source: "KernoraWindowThumbnail.qml"' "$temporary_root/desktop/usr/share/plasma/plasmoids/org.kde.plasma.taskmanager/contents/ui/ToolTipInstance.qml" \
  || fail "the task tooltip does not use the Kernora window preview"
[[ ! -e "$temporary_root/desktop/usr/share/plasma/wallpapers/org.kernora.marbles" ]] || fail "Marble Run is still installed"
[[ ! -e "$temporary_root/desktop/usr/share/plasma/wallpapers/org.kernora.tower" ]] || fail "Tower is still installed"
clipboard_ui="$temporary_root/desktop/usr/share/plasma/plasmoids/org.kernora.clipboard/contents/ui"
[[ -s "$clipboard_ui/EmojiPage.qml" && -s "$clipboard_ui/emoji.js" ]] \
  || fail "the clipboard sheet has no emoji tab"
grep -Fq '"😀","grinning face","широко улыбается"' "$clipboard_ui/emoji.js" \
  || fail "the emoji data lacks English and Russian names"
for file in FolderView.qml KernoraIconLayout.qml IconPlacement.js; do
  cmp "$project_root/packages/native/kernora-desktop/data/folderview/$file" \
    "$temporary_root/desktop/usr/share/plasma/plasmoids/org.kde.desktopcontainment/contents/ui/$file" \
    || fail "the packaged desktop icon layout differs from source: $file"
done
desktop_control=$(mktemp -d /tmp/kernora-desktop-control.XXXXXX)
dpkg-deb --control "$desktop_deb" "$desktop_control"
for file in lockscreen/LockScreen.qml osd/Osd.qml configuration/AppletConfiguration.qml \
    configuration/ConfigurationContainmentAppearance.qml configuration/ConfigurationContainmentActions.qml \
    configuration/AboutPlugin.qml configuration/ConfigurationShortcuts.qml \
    org.kde.desktopcontainment/contents/ui ConfigLocation.qml ConfigIcons.qml ConfigFilter.qml ConfigOverlay.qml FolderView.qml \
    explorer/WidgetExplorer.qml views/DesktopEditMode.qml panelconfiguration/PanelRepresentation.qml \
    org.kde.plasma.panelspacer/contents/ui/main.qml \
    org.kde.plasma.notifications/contents/ui main.qml \
    org.kde.plasma.taskmanager/contents/ui Badge.qml ToolTipInstance.qml kglobalaccel/org.kde.krunner.desktop \
    kglobalaccel/org.kde.plasma.emojier.desktop plymouth/plymouthd.defaults; do
  grep -Fq "$file" "$desktop_control/preinst" \
    || fail "Plasma's $file is not diverted before the Kernora one is unpacked"
done
for name in left_ptr pointer hand2 xterm watch left_ptr_watch grabbing size_ver nesw-resize not-allowed; do
  [[ -e "$temporary_root/desktop/usr/share/icons/kernora_cursors/cursors/$name" ]] \
    || fail "the Kernora cursor theme lacks $name"
done
frames=$(python3 -c "import struct,sys; d=open(sys.argv[1],'rb').read(); print(struct.unpack('<I', d[12:16])[0])" \
  "$temporary_root/desktop/usr/share/icons/kernora_cursors/cursors/wait")
(( frames >= 100 )) || fail "the wait cursor is not animated ($frames images)"
grep -q 'update-alternatives --install /usr/share/icons/default/index.theme x-cursor-theme' "$desktop_control/postinst" \
  || fail "Kernora's cursors do not become the default cursor theme"
grep -qx 'Bouncing=false' "$temporary_root/desktop/etc/xdg/klaunchrc" \
  || fail "the bouncing launch icon is still on"
grep -Fq 'import "kernora/global"' "$temporary_root/desktop/$notifications/main.qml" \
  || fail "the notification applet does not load the Kernora popups"
if grep -Eq '^import "global"' "$temporary_root/desktop/$notifications/main.qml"; then
  fail "the notification applet still imports Plasma's popup manager"
fi
grep -q 'dpkg-divert --package kernora-desktop --remove --rename' "$desktop_control/postrm" \
  || fail "the diversions are not removed with the package"
find "$desktop_control" -depth -delete

export LC_ALL=C
(
  cd "$temporary_root/desktop" && find . -type f
) | sort > "$temporary_root/desktop.list"
(
  cd "$temporary_root/installer" && find . -type f
) | sort > "$temporary_root/installer.list"
if comm -12 "$temporary_root/desktop.list" "$temporary_root/installer.list" \
  | grep -q .; then
  fail "the two binary packages ship an overlapping path"
fi

printf 'kernora-desktop binary test: OK\n'
