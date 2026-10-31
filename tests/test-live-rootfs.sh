#!/usr/bin/env bash
set -Eeuo pipefail

project_root=$(CDPATH= cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)
rootfs=${1:-}

fail() {
  printf 'live rootfs test: %s\n' "$*" >&2
  exit 1
}

[[ -n "$rootfs" && -d "$rootfs" ]] || fail "rootfs directory was not provided"
command -v unshare >/dev/null 2>&1 || fail "required command not found: unshare"

# shellcheck disable=SC1091
source "$project_root/configs/live/live-user.env"
# shellcheck disable=SC1091
source "$project_root/configs/upstream/base.env"
# shellcheck disable=SC1091
source "$project_root/configs/upstream/librewolf.env"
export LIVE_USER LIVE_USER_UID LIVE_USER_GROUPS LIVE_USER_PASSWORD_HASH
export LIVE_SESSION
EXCLUDED_PACKAGES=$(awk 'NF && $1 !~ /^#/ { print $1 }' \
  "$project_root/configs/live/excluded-packages.txt")
export EXCLUDED_PACKAGES
export LIBREWOLF_VERSION

snapshot_day=$(date --utc \
  --date="${SNAPSHOT_TIMESTAMP:0:4}-${SNAPSHOT_TIMESTAMP:4:2}-${SNAPSHOT_TIMESTAMP:6:2}" \
  +%s)
LIVE_USER_LASTDAY=$(( snapshot_day / 86400 ))
export LIVE_USER_LASTDAY

unshare --map-auto --setuid 0 --setgid 0 chroot "$rootfs" /bin/bash -s <<'ROOTFS_TEST'
set -Eeuo pipefail
# The image has Russian locales now: keep tool output in English for the
# checks below, whatever language the build host runs in.
export LC_ALL=C

fail() {
  printf 'inside live rootfs: %s\n' "$*" >&2
  exit 1
}

grep -Fxq 'ID=kernora' /usr/lib/os-release || fail "wrong OS identity"
[[ "$(dpkg-query -W -f='${Version}' kernora-base)" == "1.6.3" ]] \
  || fail "kernora-base is not installed"
for module in kcm_lookandfeel kcm_desktoptheme kcm_colors kcm_style kcm_icons kcm_cursortheme kcm_kwindecoration kcm_splashscreen; do
  [[ ! -e "/usr/lib/x86_64-linux-gnu/qt6/plugins/plasma/kcms/systemsettings/$module.so" ]] \
    || fail "KDE theme picker $module is still installed"
done
[[ ! -e /usr/bin/lookandfeeltool && ! -e /usr/bin/plasma-apply-lookandfeel ]] \
  || fail "KDE global theme tools are still installed"
grep -Fxq 'Exec=/usr/bin/kernora-installer --autostart' /etc/xdg/autostart/org.kernora.installer-autostart.desktop \
  || fail "the live session does not open the installer on login"
fastfetch_out=$(fastfetch --pipe true 2>/dev/null)
grep -Fq ',o000000000oo,,' <<<"$fastfetch_out" && grep -Fq 'Kernel' <<<"$fastfetch_out" \
  || fail "fastfetch does not show the Kernora logo with the system info"
[[ "$(dpkg-query -W -f='${Version}' linux-image-amd64)" == "6.12.111-1" ]] \
  || fail "wrong kernel metapackage version"
[[ "$(dpkg-query -W -f='${Version}' live-boot)" == "1:20250815~deb13u1" ]] \
  || fail "wrong live-boot version"
[[ "$(readlink -f /sbin/init)" == "/usr/lib/systemd/systemd" ]] \
  || fail "systemd is not the init system"

kernel_list=$(mktemp /tmp/kernora-kernel-list.XXXXXX)
initrd_list=$(mktemp /tmp/kernora-initrd-list.XXXXXX)
initramfs_list=$(mktemp /tmp/kernora-initramfs-list.XXXXXX)
trap 'rm -f -- "$kernel_list" "$initrd_list" "$initramfs_list"' EXIT
find /boot -maxdepth 1 -type f -name 'vmlinuz-*' | sort > "$kernel_list"
find /boot -maxdepth 1 -type f -name 'initrd.img-*' | sort > "$initrd_list"
mapfile -t kernels < "$kernel_list"
mapfile -t initrds < "$initrd_list"
(( ${#kernels[@]} == 1 )) || fail "expected exactly one kernel"
(( ${#initrds[@]} == 1 )) || fail "expected exactly one initramfs"
lsinitramfs "${initrds[0]}" > "$initramfs_list"
grep -Eq '(^|/)scripts/live($|-)' "$initramfs_list" \
  || fail "initramfs does not contain live-boot scripts"

[[ -L /etc/systemd/system/multi-user.target.wants/kernora-boot-ready.service ]] \
  || fail "boot marker service is not enabled"
grep -Fq -- '--autologin root' \
  /etc/systemd/system/getty@tty1.service.d/autologin.conf \
  || fail "live console autologin is not configured"
[[ ! -s /etc/machine-id ]] || fail "machine-id is not empty"
[[ ! -e /etc/apt/apt.conf.d/99mmdebstrap ]] \
  || fail "build-only APT settings leaked into the live system"

for package in plasma-desktop plasma-workspace systemsettings kwin-wayland \
  plasma-nm plasma-pa network-manager pipewire xdg-desktop-portal-kde; do
  [[ "$(dpkg-query -W -f='${Status}' "$package")" == 'install ok installed' ]] \
    || fail "required desktop component is not installed: $package"
done
for package in $EXCLUDED_PACKAGES; do
  status=$(dpkg-query -W -f='${Status}' "$package" 2>/dev/null || true)
  [[ "$status" != 'install ok installed' ]] \
    || fail "excluded KDE application is installed: $package"
  grep -Fxq "Package: $package" /etc/apt/preferences.d/kernora.pref \
    || fail "excluded KDE application has no APT pin: $package"
done
[[ "$(dpkg-query -W -f='${Status}' sddm)" == 'install ok installed' ]] \
  || fail "sddm is not installed"

# The Kernora Material 3 shell and what it is set in.
[[ "$(dpkg-query -W -f='${Version}' kernora-desktop)" == "1.4.56" ]] \
  || fail "kernora-desktop 1.4.56 is not installed"
for applet in org.kernora.launcher org.kernora.quicksettings; do
  [[ -s "/usr/share/plasma/plasmoids/$applet/contents/ui/main.qml" ]] \
    || fail "Kernora shell applet is missing: $applet"
done
[[ -s /usr/share/plasma/desktoptheme/kernora/widgets/panel-background.svg ]] \
  || fail "Kernora Plasma theme is missing"
find /usr/share/fonts -name 'Roboto-Regular.ttf' -print -quit | grep -q . \
  || fail "Roboto, the shell typeface, is not installed"
# Every QML module the shell imports must resolve in the image, or the applet
# (or one of its tiles) fails to load at runtime.
qml_root=/usr/lib/x86_64-linux-gnu/qt6/qml
for module in org/kde/plasma/private/kicker org/kde/plasma/private/sessions \
  org/kde/plasma/private/volume org/kde/plasma/private/brightnesscontrolplugin \
  org/kde/plasma/private/batterymonitor org/kde/plasma/private/battery \
  org/kde/plasma/networkmanagement \
  org/kde/bluezqt org/kde/notificationmanager org/kde/kcmutils \
  org/kde/coreaddons org/kde/plasma/plasma5support QtQuick/Effects; do
  [[ -s "$qml_root/$module/qmldir" ]] \
    || fail "QML module used by the shell is missing: $module"
done
# The live wallpaper, the widget style, the window decoration and the Qt Quick
# style must all resolve in the image.
[[ -s /usr/share/plasma/wallpapers/org.kernora.shapes/contents/ui/palettes/kernora.qml ]] \
  || fail "Kernora Shapes live wallpaper is missing"
# Kernora's cursors are the default, and programs start without the
# bouncing icon.
[[ "$(readlink -f /usr/share/icons/default/index.theme)" == /usr/share/icons/kernora_cursors/cursor.theme ]] \
  || fail "the default cursor theme is not Kernora's"
grep -qx 'cursorTheme=kernora_cursors' /etc/xdg/kcminputrc || fail "Plasma does not use the Kernora cursors"
grep -qx 'Bouncing=false' /etc/xdg/klaunchrc || fail "the bouncing launch icon is still on"
# The wallpapers are Kernora's live ones; no picture wallpapers ship.
for wallpaper in rhythm starfall pastel ribbon; do
  [[ -s /usr/share/plasma/wallpapers/org.kernora.$wallpaper/contents/ui/Scene.qml ]] \
    || fail "the $wallpaper live wallpaper is missing"
done
pictures=$(find /usr/share/wallpapers -type f \( -name '*.png' -o -name '*.jpg' -o -name '*.jpeg' -o -name '*.webp' -o -name '*.avif' \) 2>/dev/null | head -3 || true)
[[ -z $pictures ]] || fail "picture wallpapers are installed: $pictures"
[[ -s "$qml_root/QtQuick/Shapes/qmldir" ]] \
  || fail "Qt Quick Shapes, which draws the wallpaper, is missing"
[[ -s /usr/lib/x86_64-linux-gnu/qt6/plugins/styles/libkvantum.so ]] \
  || fail "Kvantum widget style is not installed"
[[ -s /usr/share/Kvantum/Kernora/KernoraDark.svg ]] \
  || fail "Kernora Kvantum theme is missing"
[[ -s /usr/lib/x86_64-linux-gnu/qt6/plugins/org.kde.kdecoration3/org.kde.kwin.aurorae.so ]] \
  || fail "Aurorae, which draws the Kernora window decoration, is missing"
[[ -s /usr/share/aurorae/themes/kernora/decoration.svg ]] \
  || fail "Kernora window decoration is missing"
[[ -s "$qml_root/org/kernora/desktop/qmldir" ]] \
  || fail "Kernora Qt Quick style is missing"
[[ -e /usr/lib/x86_64-linux-gnu/qt6/plugins/kf6/kirigami/platform/org.kernora.desktop.so ]] \
  || fail "Kirigami platform plugin link for the Kernora style is dangling"
# The Kernora style extends KDE's desktop style file by file; it was written
# against KDE Frameworks 6.13 and must be revisited when that changes.
[[ "$(dpkg-query -W -f='${Version}' qml6-module-org-kde-desktop)" == 6.13.* ]] \
  || fail "KDE desktop style is not the 6.13 the Kernora style extends"
grep -Fxq 'widgetStyle=kvantum-dark' /etc/xdg/kdeglobals \
  || fail "system defaults do not select the Kvantum widget style"
# The Kernora applications replace KDE's everyday tools.
[[ "$(dpkg-query -W -f='${Version}' kernora-apps)" == "1.1.65" ]] \
  || fail "kernora-apps 1.1.65 is not installed"
[[ "$(dpkg-query -W -f='${Version}' kernora-quickshare)" == "1.0.2" ]] \
  || fail "kernora-quickshare 1.0.2 is not installed"
for package in flatpak appstream; do
  [[ "$(dpkg-query -W -f='${Status}' "$package")" == 'install ok installed' ]] || fail "Store dependency missing: $package"
done
[[ -s /usr/share/flatpak/remotes.d/flathub.flatpakrepo && -s /etc/apt/apt.conf.d/60kernora-store ]] || fail "Store sources missing"
for app in settings files editor photos player calculator screenshot welcome store; do
  [[ -x "/usr/bin/kernora-$app" ]] || fail "Kernora application is missing: $app"
  [[ -s "/usr/share/kernora/$app/Main.qml" ]] || fail "interface of kernora-$app is missing"
done
for module in org/kernora/system org/kernora/store org/kernora/m3 org/kernora/ui QtMultimedia \
  org/kde/syntaxhighlighting Qt/labs/folderlistmodel QtQuick/Dialogs; do
  [[ -s "$qml_root/$module/qmldir" ]] \
    || fail "QML module used by the Kernora applications is missing: $module"
done
# KDE's System Settings command opens Kernora Settings.
[[ "$(dpkg-divert --listpackage /usr/bin/systemsettings)" == kernora-apps ]] \
  || fail "systemsettings is not diverted to Kernora Settings"
grep -Fq kernora-settings /usr/bin/systemsettings \
  || fail "systemsettings does not start Kernora Settings"
# Every program's file dialog is the Kernora chooser: the desktop portal
# picks it under Plasma, with KDE's as the fallback.
grep -qx 'org.freedesktop.impl.portal.FileChooser=kernora;kde;' /etc/xdg-desktop-portal/kde-portals.conf \
  || fail "the desktop portal does not use the Kernora file chooser"
[[ -x /usr/lib/x86_64-linux-gnu/libexec/kernora-filechooser && -s /usr/share/xdg-desktop-portal/portals/kernora.portal ]] \
  || fail "the Kernora file chooser portal is not installed"
[[ -s /usr/share/xdg-desktop-portal/portals/kde.portal ]] || fail "KDE's portal, the fallback, is missing"
# The lock screen, the OSD, the settings window and the notifications are
# Kernora's; Plasma's own stay aside.
for file in /usr/share/plasma/shells/org.kde.plasma.desktop/contents/lockscreen/LockScreen.qml \
    /usr/share/plasma/shells/org.kde.plasma.desktop/contents/osd/Osd.qml \
    /usr/share/plasma/shells/org.kde.plasma.desktop/contents/configuration/AppletConfiguration.qml \
    /usr/share/plasma/shells/org.kde.plasma.desktop/contents/configuration/ConfigurationContainmentAppearance.qml \
    /usr/share/plasma/shells/org.kde.plasma.desktop/contents/configuration/ConfigurationContainmentActions.qml \
    /usr/share/plasma/shells/org.kde.plasma.desktop/contents/configuration/AboutPlugin.qml \
    /usr/share/plasma/shells/org.kde.plasma.desktop/contents/configuration/ConfigurationShortcuts.qml \
    /usr/share/plasma/plasmoids/org.kde.desktopcontainment/contents/ui/ConfigLocation.qml \
    /usr/share/plasma/plasmoids/org.kde.desktopcontainment/contents/ui/ConfigIcons.qml \
    /usr/share/plasma/plasmoids/org.kde.desktopcontainment/contents/ui/ConfigFilter.qml \
    /usr/share/plasma/plasmoids/org.kde.plasma.notifications/contents/ui/main.qml \
    /usr/share/plasma/plasmoids/org.kde.plasma.taskmanager/contents/ui/Badge.qml \
    /usr/share/plasma/plasmoids/org.kde.plasma.taskmanager/contents/ui/ToolTipInstance.qml \
    /usr/share/kglobalaccel/org.kde.krunner.desktop \
    /usr/share/kglobalaccel/org.kde.plasma.emojier.desktop; do
  [[ "$(dpkg-divert --listpackage "$file")" == kernora-desktop ]] \
    || fail "Plasma's $file is not diverted to the Kernora one"
done
# The browser is LibreWolf, the pinned package, with the Kernora theme and
# defaults beside its own policies, and its repository for updates. Firefox
# is not installed.
[[ "$(dpkg-query -W -f='${Status}' librewolf)" == 'install ok installed' ]] \
  || fail "LibreWolf is not installed"
[[ "$(dpkg-query -W -f='${Version}' librewolf)" == "$LIBREWOLF_VERSION" ]] \
  || fail "LibreWolf is not the pinned version $LIBREWOLF_VERSION"
status=$(dpkg-query -W -f='${Status}' firefox-esr 2>/dev/null || true)
[[ "$status" != 'install ok installed' ]] || fail "Firefox is still installed"
[[ -s /usr/share/librewolf/distribution/extensions/theme@kernora.os.xpi \
  && -s /usr/share/librewolf/browser/defaults/preferences/kernora.js \
  && -s /usr/share/librewolf/distribution/policies.json ]] \
  || fail "LibreWolf lacks the Kernora theme, its defaults or its own policies"
[[ "$(readlink -f /etc/alternatives/x-www-browser)" == /usr/share/librewolf/librewolf ]] \
  || fail "LibreWolf is not the system's web browser"
grep -Fxq 'URIs: https://repo.librewolf.net' /etc/apt/sources.list.d/librewolf.sources \
  && grep -Fxq 'Signed-By: /usr/share/keyrings/librewolf-archive-keyring.gpg' /etc/apt/sources.list.d/librewolf.sources \
  && [[ -s /usr/share/keyrings/librewolf-archive-keyring.gpg ]] \
  || fail "the LibreWolf repository is not set up for updates"
grep -Fxq 'x-scheme-handler/https=librewolf.desktop;' /etc/xdg/mimeapps.list \
  || fail "LibreWolf is not the default browser"
[[ -s /usr/share/kernora/copyright/librewolf ]] || fail "LibreWolf has no copyright summary for About > Legal"
[[ -s /usr/share/kernora/librewolf/userChrome.css && -s /usr/share/kconf_update/kernora-librewolf-chrome.sh ]] \
  || fail "LibreWolf's dialogs have no Kernora style"
[[ -s /usr/share/sounds/kernora/index.theme && -s /usr/share/sounds/kernora/stereo/desktop-login.wav \
  && -s /usr/share/sounds/kernora/stereo/bell-window-system.wav ]] \
  || fail "the Kernora sound theme is missing"
grep -Fxq 'Theme=kernora' /etc/xdg/kdeglobals || fail "Plasma does not default to the Kernora sounds"
[[ "$(gsettings get org.gnome.desktop.sound theme-name 2>/dev/null)" == "'kernora'" ]] \
  || fail "GTK applications do not default to the Kernora sounds"
grep -Fxq 'Action=Sound' /etc/xdg/plasma_workspace.notifyrc || fail "the login sound is off"
grep -Fxq 'Enabled=false' /etc/xdg/kwalletrc || fail "the live session would ask to set up a wallet"
[[ -x /usr/libexec/kernora-crash-notifier \
  && -s /usr/lib/systemd/user/drkonqi-coredump-launcher@.service.d/drkonqi-coredump-launcher-kernora.conf ]] \
  || fail "crashes would open KDE's crash reporter"
[[ -s /usr/share/themes/Kernora/gtk-3.0/gtk.css && -s /usr/share/themes/Breeze/gtk-3.0/gtk.css ]] \
  || fail "the Kernora GTK theme or Breeze GTK under it is missing"
[[ "$(gsettings get org.gnome.desktop.interface gtk-theme 2>/dev/null)" == "'Kernora'" ]] \
  || fail "GTK applications do not default to the Kernora theme"
grep -Fxq 'gtk-theme-name=Kernora' "/home/$LIVE_USER/.config/gtk-3.0/settings.ini" \
  || fail "the live account does not start with the Kernora GTK theme"
[[ "$(dpkg-query -W -f='${Status}' kernora-archive)" == 'install ok installed' ]] \
  || fail "kernora-archive is not installed"
[[ ! -e /etc/apt/sources.list ]] || fail "the build's sources.list leaked into the image"
[[ ! -e /usr/share/kernora/archive ]] || fail "the build archive leaked into the image"
if grep -rq 'snapshot.debian.org\|file:/usr/share/kernora' /etc/apt/sources.list.d; then
  fail "the image still points APT at the build's sources"
fi
grep -Fxq 'Components: main non-free-firmware' /etc/apt/sources.list.d/debian.sources \
  || fail "the image takes no firmware updates"
for firmware in firmware-amd-graphics firmware-intel-graphics firmware-nvidia-graphics firmware-iwlwifi \
    firmware-realtek firmware-atheros firmware-mediatek firmware-sof-signed amd64-microcode intel-microcode; do
  [[ "$(dpkg-query -W -f='${Status}' "$firmware" 2>/dev/null)" == 'install ok installed' ]] \
    || fail "the image lacks $firmware: graphics, Wi-Fi or sound would not start on such hardware"
done
compgen -G '/usr/lib/firmware/amdgpu/gc_10_3_6_*' >/dev/null \
  || fail "the AMD Ryzen graphics firmware is missing"
grep -Fxq 'Suites: trixie-security' /etc/apt/sources.list.d/debian.sources \
  || fail "the image takes no Debian security updates"
grep -Fxq 'Signed-By: /usr/share/keyrings/kernora-archive-keyring.asc' /etc/apt/sources.list.d/kernora.sources \
  || fail "the image takes no Kernora updates"
[[ ! -e /etc/apt/sources.list.d/kernora-demo.sources ]] || fail "demo updates are on in the image"
[[ "$(/usr/libexec/kernora-update-channel status)" == stable ]] || fail "the image is not on the normal updates"
[[ -s /usr/share/keyrings/debian-archive-keyring.pgp ]] || fail "the Debian archive keyring is missing"
[[ "$(dpkg-query -W -f='${Status}' unattended-upgrades)" == 'install ok installed' ]] \
  || fail "unattended-upgrades is not installed"
apt_config=$(apt-config dump)
grep -Fq 'origin=Debian,codename=trixie-security,label=Debian-Security' <<<"$apt_config" \
  || fail "APT does not see the automatic security updates"
grep -Fxq 'APT::Periodic::Unattended-Upgrade "1";' <<<"$apt_config" \
  || fail "automatic updates are not enabled"
command -v pkexec >/dev/null || fail "pkexec is missing; the installer cannot start"
[[ "$(dpkg-query -W -f='${Version}' polkit-kde-agent-1)" == *kernora* ]] \
  || fail "the authentication agent is not Kernora's Material 3 build"
# The boot splash: Plymouth defaults to the Kernora theme, and the live
# initramfs carries it.
[[ "$(dpkg-divert --listpackage /usr/share/plymouth/plymouthd.defaults)" == kernora-desktop ]] \
  || fail "Plymouth's defaults are not Kernora's"
[[ "$(plymouth-set-default-theme)" == kernora ]] || fail "the boot splash is not the Kernora theme"
[[ -s /usr/share/plymouth/themes/kernora/kernora.script && -s /usr/share/plymouth/themes/kernora/shape-0.png ]] \
  || fail "the Kernora boot splash is incomplete"
initrd=$(find /boot -maxdepth 1 -name 'initrd.img-*' | sort | tail -n1)
lsinitramfs "$initrd" | grep -q 'usr/share/plymouth/themes/kernora/kernora.script' \
  || fail "the initramfs does not carry the Kernora boot splash"
command -v bsdtar >/dev/null || fail "bsdtar is missing; Files cannot handle archives"
[[ -x /usr/bin/kernora-installer ]] || fail "the Kernora installer launcher is missing"
[[ -s /etc/xdg/autostart/org.kernora.welcome.desktop ]] || fail "Welcome is not started at first login"
# English and Russian are ready for the live session and the installer.
for locale in en_US.utf8 ru_RU.utf8; do
  locale -a | grep -Fxq "$locale" || fail "locale is not generated: $locale"
done
[[ -x /usr/lib/kernora/live-language ]] || fail "the boot menu language cannot be applied"
[[ -L /etc/systemd/system/multi-user.target.wants/kernora-live-language.service ]] \
  || fail "the live language service is not enabled"
[[ "$(readlink -f /etc/systemd/system/default.target)" \
  == "/usr/lib/systemd/system/graphical.target" ]] \
  || fail "default target is not graphical"
[[ "$(readlink /etc/systemd/system/display-manager.service)" \
  == */sddm.service ]] || fail "SDDM is not the display manager"

# The Kernora login screen, and what it is drawn with.
grep -Fxq 'Current=kernora' /etc/sddm.conf.d/kernora-theme.conf \
  || fail "SDDM does not use the Kernora login screen"
[[ -s /usr/share/sddm/themes/kernora/Main.qml && -s /usr/lib/x86_64-linux-gnu/qt6/qml/org/kernora/m3/MShapeEcho.qml ]] \
  || fail "the Kernora login screen is incomplete"
grep -Fxq "User=${LIVE_USER:?}" /etc/sddm.conf.d/kernora-autologin.conf \
  || fail "SDDM autologin does not use the live account"
grep -Fxq "Session=${LIVE_SESSION:?}" /etc/sddm.conf.d/kernora-autologin.conf \
  || fail "SDDM autologin does not select the Plasma session"

[[ "$(id -u "${LIVE_USER:?}")" == "${LIVE_USER_UID:?}" ]] \
  || fail "live account has the wrong uid"
id -nG "${LIVE_USER:?}" | tr ' ' '\n' | grep -Fxq sudo \
  || fail "live account is not in the sudo group"
[[ -d "/home/${LIVE_USER:?}" ]] || fail "live account has no home directory"
for desktop in org.kde.plasma.emojier.desktop org.kde.drkonqi.coredump.gui.desktop kvantummanager.desktop; do
  # NoDisplay with a valid Exec: a Hidden override is discarded by KDE as an
  # invalid service, and the system entry shows in the menu again.
  override="/home/${LIVE_USER:?}/.local/share/applications/$desktop"
  grep -Fxq 'NoDisplay=true' "$override" \
    || fail "bundled Plasma utility is still visible: $desktop"
  grep -q '^Exec=' "$override" \
    || fail "menu override without Exec is ignored by KDE: $desktop"
  ! grep -Fxq 'Hidden=true' "$override" \
    || fail "Hidden override is ignored by KDE: $desktop"
done
# Check the effective application menu, including the new user's XDG overrides.
# A newly recommended KDE application must not silently slip into the image.
python3 - <<'PYTHON_TEST'
import configparser
import os
from pathlib import Path

entries = {}
for directory in (
    Path('/usr/share/applications'),
    Path('/usr/local/share/applications'),
    Path('/home') / os.environ['LIVE_USER'] / '.local/share/applications',
):
    for path in directory.glob('*.desktop'):
        entries[path.name] = path

allowed = {'systemsettings.desktop', 'kdesystemsettings.desktop'}
unexpected = []
for name, path in sorted(entries.items()):
    parser = configparser.ConfigParser(interpolation=None, strict=False)
    parser.read(path)
    entry = parser['Desktop Entry']
    if entry.getboolean('Hidden', fallback=False) or entry.getboolean('NoDisplay', fallback=False):
        continue
    if 'KDE' in entry.get('Categories', '').split(';') and name not in allowed:
        unexpected.append(name)
if unexpected:
    raise SystemExit('Unexpected KDE menu applications: ' + ', '.join(unexpected))
print('KDE application menu test: OK')
PYTHON_TEST
[[ "$(getent shadow "${LIVE_USER:?}" | cut -d: -f2)" \
  == "${LIVE_USER_PASSWORD_HASH:?}" ]] \
  || fail "live account password hash is not the pinned one"
[[ "$(getent shadow "${LIVE_USER:?}" | cut -d: -f3)" \
  == "${LIVE_USER_LASTDAY:?}" ]] \
  || fail "live account is not aged to the snapshot day"

grep -Fxq 'After=plymouth-quit.service' \
  /usr/lib/systemd/system/sddm.service.d/sddm-plymouth.conf \
  || fail "SDDM does not wait for the boot display to be released"
grep -Fxq 'ExecStart=-/usr/bin/plymouth quit' \
  /usr/lib/systemd/system/plymouth-quit.service.d/plymouth-quit-kernora.conf \
  || fail "Plymouth would retain the splash when Xorg takes over"

live_owner=$(stat -c '%u:%g' "/home/$LIVE_USER")
chown 1000:1000 /
/var/lib/dpkg/info/kernora-base.postinst configure
[[ "$(stat -c '%u:%g:%a' /)" == '0:0:755' ]] \
  || fail "kernora-base upgrade does not repair the root inode"
[[ "$(stat -c '%u:%g' "/home/$LIVE_USER")" == "$live_owner" ]] \
  || fail "root ownership migration changed the live account owner"

printf 'inside live rootfs: OK\n'
ROOTFS_TEST

printf 'live rootfs test: OK\n'
