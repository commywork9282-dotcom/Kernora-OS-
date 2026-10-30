#!/usr/bin/env bash
set -Eeuo pipefail

project_root=$(CDPATH= cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)
package_root="$project_root/packages/native/kernora-desktop"

fail() {
  printf 'kernora-desktop source test: %s\n' "$*" >&2
  exit 1
}

for dependency in dpkg-parsechangelog grep python3; do
  command -v "$dependency" >/dev/null 2>&1 \
    || fail "required command not found: $dependency"
done

version=$(dpkg-parsechangelog -l"$package_root/debian/changelog" -S Version)
distribution=$(dpkg-parsechangelog \
  -l"$package_root/debian/changelog" -S Distribution)
[[ "$version" == "1.4.55" ]] || fail "unexpected source version"
[[ "$distribution" == "UNRELEASED" ]] \
  || fail "development package must remain UNRELEASED"
[[ "$(<"$package_root/debian/source/format")" == "3.0 (native)" ]] \
  || fail "wrong source format"
[[ -x "$package_root/debian/rules" ]] || fail "debian/rules is not executable"

control="$package_root/debian/control"
grep -Fxq 'Package: kernora-desktop' "$control" \
  || fail "desktop binary stanza is missing"
grep -Fxq 'Package: kernora-calamares' "$control" \
  || fail "installer binary stanza is missing"
grep -Fxq 'Standards-Version: 4.7.4' "$control" \
  || fail "wrong Standards-Version"
grep -Eq '^ calamares \(>= [^)]*kernora[0-9]+\),$' "$control" \
  || fail "installer configuration does not depend on the Kernora calamares"

data_root="$package_root/data"
for wallpaper in shapes rhythm starfall pastel ribbon; do
  for file in metadata.json contents/ui/main.qml contents/ui/Scene.qml contents/ui/config.qml contents/config/main.xml; do
    [[ -s "$data_root/wallpaper/org.kernora.$wallpaper/$file" ]] \
      || fail "the $wallpaper wallpaper lacks $file"
  done
  [[ -s "$package_root/data/shell/po/plasma_wallpaper_org.kernora.$wallpaper.ru.po" ]] \
    || fail "the $wallpaper wallpaper has no Russian translation"
done
grep -Fq 'import "morphs.js" as Morphs' "$data_root/wallpaper/org.kernora.ribbon/contents/ui/Scene.qml" \
  && grep -Fq 'readonly property int to: (5 * slot + 1) % scene.kinds' "$data_root/wallpaper/org.kernora.ribbon/contents/ui/Scene.qml" \
  && grep -Fq '"ribbon": {' "$package_root/tools/gen-wallpaper-assets" \
  || fail "Ribbon's shapes do not change into one another"
ribbon_assets=$(mktemp -d)
python3 "$package_root/tools/gen-wallpaper-assets" "$ribbon_assets" ribbon >/dev/null \
  && python3 - "$ribbon_assets/morphs.js" <<'PY' || fail "gen-wallpaper-assets does not write Ribbon's morphs"
import json, re, sys
text = open(sys.argv[1]).read()
samples = int(re.search(r"var samples = (\d+);", text).group(1))
names = json.loads(re.search(r"var names = (\[.*?\]);", text).group(1))
shapes = json.loads(re.search(r"var shapes = (\[.*\]);", text, re.S).group(1))
assert len(names) == len(shapes) == 16 and "puffy" not in names
assert all(len(radii) == samples and 0.2 < min(radii) and max(radii) < 0.75 for radii in shapes)
PY
rm -rf "$ribbon_assets"
[[ ! -e "$data_root/wallpaper/org.kernora.tower" ]] || fail "Tower is back"
[[ ! -e "$package_root/data/shell/po/plasma_wallpaper_org.kernora.tower.ru.po" ]] || fail "Tower still has a translation"
grep -q '"tower"' "$package_root/tools/gen-wallpaper-assets" && fail "gen-wallpaper-assets still has a Tower palette"
[[ ! -e "$data_root/wallpaper/org.kernora.marbles" ]] || fail "Marble Run is back"
sh -n "$package_root/data/kconf_update/kernora-marbles-to-pastel.sh" || fail "the Marble Run migration does not parse"
marbles_home=$(mktemp -d)
printf '[Greeter]\nWallpaperPlugin=org.kernora.marbles\n' > "$marbles_home/kscreenlockerrc"
XDG_CONFIG_HOME="$marbles_home" sh "$package_root/data/kconf_update/kernora-marbles-to-pastel.sh"
grep -Fxq 'WallpaperPlugin=org.kernora.pastel' "$marbles_home/kscreenlockerrc" \
  || fail "a lock screen with Marble Run does not move to Pastel"
grep -Fq '"org.kernora.pastel"' "$package_root/data/shell-updates/kernora_marbles_to_pastel.js" \
  || fail "desktops with Marble Run do not move to Pastel"
rm -rf "$marbles_home"
sh -n "$package_root/data/kconf_update/kernora-tower-to-shapes.sh" || fail "the Tower migration does not parse"
tower_home=$(mktemp -d)
printf '[Greeter]\nWallpaperPlugin=org.kernora.tower\n' > "$tower_home/kscreenlockerrc"
XDG_CONFIG_HOME="$tower_home" sh "$package_root/data/kconf_update/kernora-tower-to-shapes.sh"
grep -Fxq 'WallpaperPlugin=org.kernora.shapes' "$tower_home/kscreenlockerrc" \
  || fail "a lock screen with Tower does not move to Shapes"
grep -Fq '"org.kernora.shapes"' "$package_root/data/shell-updates/kernora_tower_to_shapes.js" \
  || fail "desktops with Tower do not move to Shapes"
grep -Fq 'wallpaper=org.kernora.shapes' "$package_root/debian/kernora-desktop.postinst" \
  || fail "a login screen with Tower does not move to Shapes"
rm -rf "$tower_home"
sh -n "$package_root/data/plasma-env/kernora-video-decoding.sh" || fail "the VLC decoding script does not parse"
video_home=$(mktemp -d)
mkdir -p "$video_home/sys/module/nvidia" "$video_home/.var/app/org.videolan.VLC/config/vlc"
printf '[avcodec]\navcodec-hw=vaapi_drm\n' > "$video_home/.var/app/org.videolan.VLC/config/vlc/vlcrc"
for run in 1 2; do
  HOME="$video_home" XDG_CONFIG_HOME="$video_home/.config" XDG_STATE_HOME="$video_home/.local/state" KERNORA_SYSFS="$video_home/sys" \
    sh -c ". '$package_root/data/plasma-env/kernora-video-decoding.sh'"
done
[[ "$(grep -c '^avcodec-hw=none$' "$video_home/.config/vlc/vlcrc")" == 1 ]] || fail "VLC keeps hardware decoding on NVIDIA"
grep -Fxq 'avcodec-hw=vaapi_drm' "$video_home/.var/app/org.videolan.VLC/config/vlc/vlcrc" \
  && ! grep -q 'avcodec-hw=none' "$video_home/.var/app/org.videolan.VLC/config/vlc/vlcrc" \
  || fail "a VLC decoder chosen by the user is overridden"
rm -rf "$video_home/.config" "$video_home/.local"
rm -rf "$video_home/sys/module/nvidia"
HOME="$video_home" XDG_CONFIG_HOME="$video_home/.config" XDG_STATE_HOME="$video_home/.local/state" KERNORA_SYSFS="$video_home/sys" \
  sh -c ". '$package_root/data/plasma-env/kernora-video-decoding.sh'"
[[ ! -e "$video_home/.config/vlc/vlcrc" ]] || fail "VLC decoding changes without an NVIDIA driver"
rm -rf "$video_home"
assets=$(mktemp -d)
python3 "$package_root/tools/gen-wallpaper-assets" "$assets" pastel >/dev/null \
  || fail "gen-wallpaper-assets cannot write Pastel's assets"
grep -q '"hull":\[\[' "$assets/materialshapes.js" || fail "the shapes have no hulls"
grep -q '"base"' "$assets/palettes/kernora.qml" || fail "Pastel's palette has no base"
KERNORA_COLOUR=blue python3 "$package_root/tools/gen-wallpaper-assets" "$assets" pastel >/dev/null \
  || fail "gen-wallpaper-assets cannot write Pastel's blue palette"
cmp -s "$assets/palettes/kernora.qml" "$assets/palettes/blue.qml" && fail "the wallpaper does not change with the colour"
rm -rf "$assets"
palettes=$(mktemp -d)
for colour in kernora blue grey; do
  KERNORA_COLOUR=$colour python3 "$package_root/tools/gen-qml-tokens" --palette "$palettes/$colour.conf" >/dev/null \
    || fail "no $colour palette"
done
grep -Fxq 'id=blue' "$palettes/blue.conf" || fail "the blue palette does not name itself"
grep -Fxq '[md1-light]' "$palettes/blue.conf" || fail "the blue palette lacks Material Design 1"
python3 - "$palettes/grey.conf" <<'PYTHON_TEST' || fail "the grey theme is not grey"
import configparser, sys
c = configparser.ConfigParser(interpolation=None)
c.optionxform = str
c.read(sys.argv[1])
rgb = bytes.fromhex(c["md3-dark"]["primary"])
assert max(rgb) - min(rgb) <= 6, rgb.hex()
PYTHON_TEST
KERNORA_COLOUR=violet python3 "$package_root/tools/gen-qml-tokens" --palette "$palettes/x.conf" >/dev/null 2>&1 \
  && fail "an unknown colour was accepted"
rm -rf "$palettes"
[[ ! -e "$data_root/wallpapers" ]] || fail "picture wallpapers are back in the package"
grep -Fxq 'path-exclude=/usr/share/wallpapers/Next/*' "$data_root/dpkg/kernora-wallpapers" \
  || fail "Breeze's picture wallpaper is not kept out"

defaults="$data_root/look-and-feel/org.kernora.desktop/contents/defaults"
[[ -s "$defaults" ]] || fail "look-and-feel defaults are missing"
grep -Fq 'wallpaperPlugin = "org.kernora.shapes"' "$data_root/look-and-feel/org.kernora.desktop/contents/layouts/org.kde.plasma.desktop-layout.js" \
  || fail "the default layout does not use Kernora Shapes"
grep -Fxq 'cursorTheme=kernora_cursors' "$defaults" \
  || fail "look-and-feel does not select the Kernora cursors"
[[ -x "$package_root/tools/gen-cursor-theme" ]] || fail "the cursor theme generator is missing"
grep -Fxq 'Theme=Kernora' "$defaults" \
  || fail "look-and-feel does not select the Kernora icon theme"
grep -Fxq 'Theme=org.kernora.desktop' "$defaults" \
  || fail "look-and-feel does not select the Kernora session splash"
grep -Fq 'loglevel=3' "$package_root/data/grub/kernora.cfg" \
  && grep -Fq 'update-grub' "$package_root/debian/kernora-desktop.postinst" \
  || fail "installed systems print kernel errors over the boot splash"
grep -Fq 'dpkg-trigger --no-await update-initramfs' "$package_root/debian/kernora-desktop.postinst" \
  && grep -Fq '/var/lib/kernora/plymouth-theme' "$package_root/debian/kernora-desktop.postrm" \
  || fail "a changed boot splash does not reach the initramfs on upgrade"
grep -Fq 'Keys.onReturnPressed: event => event.accepted = true' "$package_root/data/widgets/common/CityPicker.qml" \
  || fail "Enter in the city search closes the widget settings"
grep -Fq 'property Timer watch' "$package_root/data/widgets/common/WeatherModel.qml" \
  && grep -Fq 'text: weather.city' "$package_root/data/widgets/weather/contents/ui/main.qml" \
  || fail "the weather widget does not show the chosen city"
grep -Fq 'function commit()' "$package_root/data/widgets/common/CityPicker.qml" \
  && grep -Fq 'picker.commit()' "$package_root/data/widgets/weather/contents/ui/ConfigLocation.qml" \
  && grep -Fq 'picker.commit()' "$package_root/data/widgets/glance/contents/ui/ConfigWeather.qml" \
  && grep -Fq 'onTextChanged: typing.restart()' "$package_root/data/widgets/common/CityPicker.qml" \
  || fail "the weather city does not follow Apply or does not search while typing"
grep -Fq 'readonly property bool shown: Plasmoid.configuration.interactiveMute' "$package_root/data/taskmanager/AudioStream.qml" \
  && grep -Fq '"$tasks/AudioStream.qml"' "$package_root/debian/kernora-desktop.preinst" \
  && grep -Fq '"$tasks/AudioStream.qml"' "$package_root/debian/kernora-desktop.postrm" \
  || fail "the task audio indicator ignores its setting"
grep -Fq 'RightButton;NoModifier=org.kde.contextmenu' "$package_root/data/kconf_update/kernora-add-widgets-menu.sh" \
  || fail "a new user's desktop can lose its right-click menu"
drivers="$package_root/data/drivers"
bash -n "$drivers/kernora-drivers" || fail "kernora-drivers is not valid bash"
[[ -x "$drivers/kernora-drivers" ]] || fail "kernora-drivers is not executable"
[[ "$(gpg --show-keys --with-colons "$drivers/nvidia-archive-keyring.gpg" 2>/dev/null | awk -F: '$1 == "fpr" {print $10; exit}')" == 02182E60104FCDC26EAE1B8597A5D4CB8793F200 ]] \
  || fail "the NVIDIA archive key is not NVIDIA's Debian 13 key"
grep -Fq 'OnActiveSec=90s' "$drivers/kernora-drivers.timer" \
  && grep -Fq 'ExecStart=/usr/libexec/kernora-drivers auto' "$drivers/kernora-drivers.service" \
  && grep -Fq 'ExecStart=/usr/libexec/kernora-drivers %i' "$drivers/kernora-drivers@.service" \
  || fail "the driver check is not scheduled"
grep -Fq '<annotate key="org.freedesktop.policykit.exec.path">/usr/libexec/kernora-drivers</annotate>' "$drivers/org.kernora.drivers.policy" \
  || fail "Settings cannot run kernora-drivers"
grep -Fxq '  - shellprocess@drivers' "$package_root/data/calamares/settings.conf" \
  && grep -Fq 'kernora-drivers install --target' "$package_root/data/calamares/modules/shellprocess-drivers.conf" \
  || fail "the installer does not install graphics drivers"
grep -Fxq 'ColorScheme=KernoraDark' "$defaults" \
  || fail "look-and-feel does not select the Kernora colour scheme"
grep -Fxq 'name=kernora' "$defaults" \
  || fail "look-and-feel does not select the Kernora Plasma theme"

tools_root="$package_root/tools"
python3 "$project_root/tests/test-panel-transparency.py" || fail "panel transparency variants are inconsistent"
for tool in gen-color-schemes gen-icon-theme gen-kdeglobals gen-plasma-theme \
  gen-qml-tokens gen-translations fetch-symbols gen-wallpaper-assets \
  gen-kvantum-theme gen-aurorae-theme gen-avatar gen-avatars gen-terminal-theme gen-greeter-palette \
  gen-keyboard-maps gen-qm gen-installer-icons gen-installer-style gen-browser-theme gen-gtk-theme gen-sound-theme gen-plymouth-theme gen-grub-theme gen-emoji-data; do
  [[ -x "$tools_root/$tool" ]] || fail "design-system tool missing: $tool"
done
grep -Fxq 'pref("extensions.activeThemeID", "theme@kernora.os");' "$package_root/data/librewolf/kernora.js" \
  || fail "LibreWolf does not default to the Kernora theme"
grep -Fxq 'pref("widget.use-xdg-desktop-portal.file-picker", 1);' "$package_root/data/librewolf/kernora.js" \
  || fail "LibreWolf does not pick files in the Kernora chooser"
mimeapps="$package_root/data/xdg-mimeapps/mimeapps.list"
for default in 'x-scheme-handler/https=librewolf.desktop;' 'text/html=librewolf.desktop;' \
  'image/png=org.kernora.photos.desktop;' 'application/json=org.kernora.editor.desktop;'; do
  grep -Fxq "$default" "$mimeapps" || fail "mimeapps.list lacks $default"
done
grep -Fxq "gtk-theme='Kernora'" "$package_root/data/gtk/90_kernora.gschema.override" \
  || fail "GTK applications do not default to the Kernora theme"
for version in 3.0 4.0; do
  grep -Fxq 'gtk-theme-name=Kernora' "$package_root/data/skel-config/gtk-$version/settings.ini" \
    || fail "new accounts do not start with the Kernora GTK $version theme"
done
sh -n "$package_root/data/kconf_update/kernora-gtk-theme.sh" || fail "the GTK theme migration does not parse"
gtk_themes=$(mktemp -d)
for generation in md1 md2 md3; do
  KERNORA_GENERATION=$generation python3 "$tools_root/gen-gtk-theme" "$gtk_themes" >/dev/null \
    || fail "gen-gtk-theme fails for $generation"
done
for theme in Kernora KernoraMD1 KernoraMD2; do
  for file in gtk-3.0/gtk.css gtk-3.0/gtk-dark.css gtk-4.0/gtk.css gtk-4.0/gtk-dark.css; do
    grep -q '@import url("../../Breeze/' "$gtk_themes/$theme/$file" || fail "$theme/$file does not build on Breeze"
  done
done
rm -rf "$gtk_themes"
grep -Fxq 'pref("toolkit.legacyUserProfileCustomizations.stylesheets", true);' "$package_root/data/librewolf/kernora.js" \
  || fail "LibreWolf does not load the Kernora dialog style"
link_script="$package_root/data/kconf_update/kernora-librewolf-chrome.sh"
sh -n "$link_script" || fail "the LibreWolf dialog style script does not parse"
browser=$(mktemp -d)
python3 "$tools_root/gen-browser-theme" "$browser/theme.xpi" "$browser/userChrome.css" >/dev/null \
  || fail "gen-browser-theme fails"
grep -Fq 'button[dlgtype][default] {' "$browser/userChrome.css" \
  || fail "the LibreWolf dialog style does not fill the default button"
sed "s|^sheet=.*|sheet=$browser/userChrome.css|" "$link_script" > "$browser/link.sh"
HOME="$browser/new" XDG_CONFIG_HOME="$browser/new/.config" sh "$browser/link.sh"
new_root="$browser/new/.config/librewolf/librewolf"
[[ "$(readlink "$new_root/kernora.default-default/chrome/userChrome.css")" == "$browser/userChrome.css" ]] \
  || fail "a new account's LibreWolf profile does not get the Kernora dialog style"
grep -Fxq '[Install6C4726F70D182CF7]' "$new_root/profiles.ini" \
  && grep -Fxq 'Default=kernora.default-default' "$new_root/installs.ini" \
  || fail "LibreWolf would not use the prepared profile"
own_root="$browser/own/.config/librewolf/librewolf"
mkdir -p "$own_root/mine.default/chrome" "$own_root/plain.default"
printf '[Profile0]\nIsRelative=1\nPath=mine.default\n\n[Profile1]\nIsRelative=1\nPath=plain.default\n' > "$own_root/profiles.ini"
printf 'own\n' > "$own_root/mine.default/chrome/userChrome.css"
HOME="$browser/own" XDG_CONFIG_HOME="$browser/own/.config" sh "$browser/link.sh"
[[ "$(<"$own_root/mine.default/chrome/userChrome.css")" == own ]] \
  || fail "the Kernora dialog style replaced a user's own userChrome.css"
[[ "$(readlink "$own_root/plain.default/chrome/userChrome.css")" == "$browser/userChrome.css" ]] \
  || fail "an existing LibreWolf profile does not get the Kernora dialog style"
[[ ! -e "$own_root/kernora.default-default" ]] || fail "a profile was added next to existing ones"
rm -rf "$browser"
grep -Fxq "theme-name='kernora'" "$package_root/data/gtk/90_kernora.gschema.override" \
  || fail "GTK applications do not default to the Kernora sounds"
grep -Fxq 'gtk-sound-theme-name=kernora' "$package_root/data/skel-config/gtk-3.0/settings.ini" \
  || fail "new accounts do not start with the Kernora sounds"
sh -n "$package_root/data/kconf_update/kernora-sound-theme.sh" || fail "the sound theme migration does not parse"
sh -n "$package_root/data/kconf_update/kernora-terminal-entry.sh" || fail "the terminal entry migration does not parse"
sh -n "$package_root/data/kconf_update/kernora-add-widgets-menu.sh" || fail "the widgets menu migration does not parse"
menu_home=$(mktemp -d)
XDG_CONFIG_HOME="$menu_home" sh "$package_root/data/kconf_update/kernora-add-widgets-menu.sh"
XDG_CONFIG_HOME="$menu_home" sh "$package_root/data/kconf_update/kernora-add-widgets-menu.sh"
[[ "$(grep -c "add widgets=true" "$menu_home/plasma-org.kde.plasma.desktop-appletsrc")" == 1 ]] \
  || fail "the desktop menu does not offer Add Widgets exactly once"
rm -rf "$menu_home"
sh -n "$package_root/data/crash/kernora-panic-report" || fail "the panic report does not parse"
for widget in clock glance weather battery calendar media photo note; do
  python3 -c 'import json,sys; json.load(open(sys.argv[1]))' "$package_root/data/widgets/$widget/metadata.json" \
    || fail "the $widget widget metadata is not JSON"
  xmllint --noout "$package_root/data/widgets/$widget/contents/config/main.xml" \
    || fail "the $widget widget configuration is not XML"
  grep -q "^WIDGETS = .*\b$widget\b" "$package_root/debian/rules" || fail "the $widget widget is not built"
done
for po in "$package_root"/data/shell/po/plasma_applet_org.kernora.widget.*.ru.po; do
  msgfmt -c -o /dev/null "$po" 2>/dev/null || fail "$(basename "$po") does not compile"
done
grep -Fq 'api.open-meteo.com/v1/forecast' "$package_root/data/widgets/common/WeatherModel.qml" \
  || fail "the weather widgets do not use Open-Meteo"
grep -Fxq 'kernel.panic = 10' "$package_root/data/crash/90-kernora-panic.conf" \
  || fail "a kernel panic would not restart the computer"
python3 "$tools_root/check-contrast" >/dev/null || fail "a colour theme draws text or icons that blend into their background"
grep -Fxq '  - shellprocess@upgrade' "$package_root/data/calamares/settings.conf" \
  || fail "the installer does not bring the new system up to date"
grep -Fq 'full-upgrade' "$package_root/data/calamares/modules/shellprocess-upgrade.conf" \
  || fail "the installer's update step does not upgrade"
sounds=$(mktemp -d)
python3 "$tools_root/gen-sound-theme" "$sounds" desktop-login,bell >/dev/null || fail "gen-sound-theme fails"
grep -Fxq 'Inherits=freedesktop' "$sounds/kernora/index.theme" || fail "the sound theme does not fall back to freedesktop"
[[ "$(head -c 4 "$sounds/kernora/stereo/desktop-login.wav")" == RIFF ]] || fail "the login sound is not a WAV file"
[[ "$(readlink "$sounds/kernora/stereo/bell-window-system.wav")" == bell.wav ]] || fail "the window bell does not use the bell sound"
rm -rf "$sounds"
avatars=$(mktemp -d)
python3 "$tools_root/gen-avatars" "$avatars" >/dev/null || fail "gen-avatars fails"
[[ "$(find "$avatars" -name '*.svg' | wc -l)" -eq 14 ]] || fail "the profile pictures are not fourteen plus the Kernora mark"
grep -l '<path ' "$avatars"/*.svg | wc -l | grep -qx 14 || fail "a profile picture has no waves"
rm -rf "$avatars"
if grep -rIl 'firefox-esr' "$package_root/data" >/dev/null; then
  fail "the desktop still refers to Firefox: $(grep -rIl 'firefox-esr' "$package_root/data" | head -1)"
fi
PYTHONDONTWRITEBYTECODE=1 python3 - "$tools_root" <<'PY' || fail "the Material generations are incomplete"
import sys
sys.path.insert(0, sys.argv[1])
import kernora_design as design
roles = set(design.palette("md3", True))
for generation in design.GENERATIONS:
    for dark in (True, False):
        assert set(design.palette(generation, dark)) == roles, (generation, dark)
for kind, values in design.CORNERS.items():
    assert len(values) == len(design.GENERATIONS), kind
for kind, values in design.ELEVATION_LEVEL.items():
    assert len(values) == len(design.GENERATIONS), kind
PY
icons=$(mktemp -d)
python3 "$tools_root/gen-icon-theme" "$package_root/data/symbols" "$icons/Kernora" >/dev/null \
  || fail "gen-icon-theme fails"
grep -Fxq 'Inherits=breeze-dark,breeze,hicolor' "$icons/Kernora/index.theme" \
  || fail "icon theme does not inherit Breeze and would lose every other icon"
KERNORA_COLOUR=blue python3 "$tools_root/gen-icon-theme" "$package_root/data/symbols" "$icons/Kernora-blue" >/dev/null \
  || fail "gen-icon-theme fails for a colour"
grep -Fxq 'Inherits=Kernora,breeze-dark,breeze,hicolor' "$icons/Kernora-blue/index.theme" \
  || fail "a colour's icons do not fall back to Kernora's"
[[ "$(find "$icons/Kernora-blue/scalable" -name '*.svg' -type f | wc -l)" -eq 14 ]] \
  || fail "a colour's icon theme should hold only the fourteen app icons"
for icon in actions/kernora-quickshare status/kernora-tile-quickshare-on apps/org.kernora.quickshare; do
  [[ -e "$icons/Kernora/scalable/$icon.svg" ]] || fail "the icon theme has no $icon"
done
find "$icons/Kernora-blue" -name 'preferences-system*' | grep -q . \
  && fail "a colour's icons would shadow preferences-system-* through KDE's generic fallback"
python3 - "$package_root/data/explorer" "$icons/Kernora" <<'PY' || fail "the widget picker uses an icon or a preview Kernora does not have"
import pathlib, re, sys
explorer, theme = pathlib.Path(sys.argv[1]), pathlib.Path(sys.argv[2])
table = (explorer / "widgets.js").read_text()
preview = (explorer / "OtherPreview.qml").read_text()
names = set(re.findall(r'(?:icon|badge|glyph|trailing): "([^"]+)"', table))
for group in re.findall(r'buttons: \[([^\]]*)\]', table):
    names.update(re.findall(r'"([^"]+)"', group))
names.update(re.findall(r'(?:source|icon): "([^"]+)"', preview))
for group in re.findall(r'model: \[([^\]]*)\]', preview, re.S):
    names.update(re.findall(r'"([a-z][a-z0-9.-]*)"', group))
names -= {"primary", "secondary", "tertiary"}
have = {path.stem for path in theme.glob("scalable/*/*.svg")} | {"start-here-kde-symbolic"}
missing = sorted(names - have)
assert not missing, missing
cases = set(re.findall(r'case "([a-z]+)":', preview)) | {"glyph", "button"}
kinds = set(re.findall(r'(?:preview|content): "([a-z]+)"', table))
assert kinds <= cases, sorted(kinds - cases)
PY
rm -rf "$icons"
grep -Fq 'LookAndFeelPackage=org.kernora.desktop' "$tools_root/gen-kdeglobals" \
  || fail "Kernora look-and-feel is not the system default"
PYTHONDONTWRITEBYTECODE=1 python3 "$tools_root/fetch-symbols" --check >/dev/null \
  || fail "vendored Material Symbols do not match data/symbols.lock"
[[ -s "$data_root/symbols/LICENSE" ]] || fail "Material Symbols licence is missing"
[[ -x "$tools_root/draw-symbols" ]] || fail "draw-symbols is missing"
grep -Eq '^[0-9a-f]{64}  kernora_quick_share_(fill1_)?24px.svg$' "$data_root/symbols.lock" \
  || fail "the Quick Share symbol is not in data/symbols.lock"
grep -Fxq 'MShape MShape.qml' "$data_root/shell/m3/qmldir" || fail "m3 has no MShape"

shell_root="$data_root/shell"
for applet in launcher:org.kernora.launcher shade:org.kernora.quicksettings clipboard:org.kernora.clipboard; do
  directory=${applet%%:*}
  id=${applet#*:}
  grep -Fq "\"Id\": \"$id\"" "$shell_root/$directory/metadata.json" \
    || fail "applet $directory does not declare the id $id"
  [[ -s "$shell_root/$directory/contents/ui/main.qml" ]] \
    || fail "applet $directory has no main.qml"
  grep -Fq "\"$id\"" \
    "$data_root/look-and-feel/org.kernora.desktop/contents/layouts/org.kde.plasma.desktop-layout.js" \
    || fail "default layout does not place $id"
  [[ -s "$shell_root/po/plasma_applet_$id.ru.po" ]] \
    || fail "applet $id has no Russian catalog"
done
while read -r first second third; do
  file=$second
  [[ "$first" == "singleton" ]] && file=$third
  [[ "$file" == "M3.qml" || -s "$shell_root/m3/$file" ]] \
    || fail "qmldir names a missing component: $file"
done < "$shell_root/m3/qmldir"
if grep -rEn 'M3\.on[A-Z]' "$shell_root" "$data_root/style" >/dev/null; then
  fail "QML uses an M3.on* role; use the *Content spelling"
fi

wallpaper_plugin="$data_root/wallpaper/org.kernora.shapes"
grep -Fq '"Id": "org.kernora.shapes"' "$wallpaper_plugin/metadata.json" \
  || fail "live wallpaper does not declare its id"
for file in main.qml Scene.qml choreography.js config.qml; do
  [[ -s "$wallpaper_plugin/contents/ui/$file" ]] \
    || fail "live wallpaper is missing $file"
done
grep -Fq '"org.kernora.shapes"' \
  "$data_root/look-and-feel/org.kernora.desktop/contents/layouts/org.kde.plasma.desktop-layout.js" \
  || fail "default layout does not select the live wallpaper"

style="$data_root/style/org.kernora.desktop"
grep -Fxq 'module org.kernora.desktop' "$style/qmldir" \
  || fail "Qt Quick style module is misnamed"
grep -Fxq 'import org.kde.desktop auto' "$style/qmldir" \
  || fail "Qt Quick style has no fallback to the desktop style"
while read -r type _version file; do
  [[ "$type" == module || "$type" == import ]] && continue
  [[ -s "$style/$file" ]] || fail "Qt Quick style names a missing control: $file"
done < "$style/qmldir"
grep -Fxq 'export QT_QUICK_CONTROLS_STYLE=org.kernora.desktop' \
  "$data_root/plasma-env/kernora-qtquick-style.sh" \
  || fail "the session does not select the Kernora Qt Quick style"
grep -Fq 'org.kernora.desktop.so' "$package_root/debian/kernora-desktop.links" \
  || fail "Kirigami has no platform plugin under the Kernora style name"

grep -Fxq 'widgetStyle=kvantum-dark' "$defaults" \
  || fail "look-and-feel does not select the Kvantum widget style"
grep -Fxq 'theme=__aurorae__svg__kernora' "$defaults" \
  || fail "look-and-feel does not select the Kernora window decoration"
grep -Fxq 'theme=Kernora' "$data_root/kvantum/kvantum.kvconfig" \
  || fail "Kvantum does not default to the Kernora theme"
grep -Fq '"widgetStyle=kvantum-dark"' "$tools_root/gen-kdeglobals" \
  || fail "system defaults do not select the Kvantum widget style"
if grep -Fq '"AccentColor"' "$tools_root/kde_colors.py"; then
  fail "colour schemes carry an accent colour"
fi
splash="$data_root/look-and-feel/org.kernora.desktop/contents/splash/Splash.qml"
[[ -s "$splash" ]] || fail "session splash is missing"
if grep '^import' "$splash" | grep -Evq '^import (QtQuick|QtQuick\.Window|org\.kernora\.m3)$'; then
  fail "splash imports something unexpected"
fi
grep -Fq 'source: "file:///var/lib/kernora/greeter/wallpaper.qml"' "$splash" \
  && grep -Fq 'return (offset + Date.now() / 1000 / loop) % 1;' "$splash" \
  && ! grep -Fq 'MCircularProgress' "$splash" && ! grep -Fq 'kernora.png' "$splash" \
  || fail "the session splash is a loading screen instead of the wallpaper"
grep -Fxq 'Current=kernora' "$data_root/sddm.conf.d/kernora-theme.conf" \
  || fail "greeter does not use the Kernora login screen"
grep -Fxq 'InputMethod=' "$data_root/sddm.conf.d/kernora-theme.conf" \
  || fail "the login screen would show the virtual keyboard"
[[ -s "$data_root/sddm-theme/kernora/Main.qml" ]] || fail "the Kernora login screen is missing"

settings="$data_root/calamares/settings.conf"
[[ -s "$settings" ]] || fail "installer settings are missing"
grep -Fxq 'branding: kernora' "$settings" \
  || fail "installer does not use the Kernora branding"
for module in partition mount unpackfs users removeuser bootloader umount; do
  grep -Fq "  - $module" "$settings" \
    || fail "installer sequence is missing the $module module"
done

for page in $(awk '/^  - [a-z]+q$/ { print $2 }' "$settings" | sort -u); do
  [[ -s "$data_root/calamares/branding/kernora/$page.qml" ]] \
    || fail "installer page has no Kernora QML: $page"
done
keymaps="$data_root/calamares/branding/kernora/keymaps.js"
for layout in '"us":' '"ru":' '"ru(phonetic)":' '"de":'; do
  grep -Fq "$layout" "$keymaps" || fail "keyboard table lacks $layout"
done

scratch_qm=$(mktemp)
python3 "$tools_root/gen-qm" "$data_root/calamares/lang/calamares-kernora_ru.ts" "$scratch_qm" >/dev/null \
  || fail "the installer's Russian supplement does not compile"
rm -f "$scratch_qm"

for config in unpackfs users removeuser shellprocess bootloader packages partition; do
  [[ -s "$data_root/calamares/modules/$config.conf" ]] \
    || fail "missing module configuration: $config.conf"
done

# shellcheck disable=SC1091
source "$project_root/configs/live/live-user.env"
grep -Fxq "username: $LIVE_USER" "$data_root/calamares/modules/removeuser.conf" \
  || fail "installer does not remove the live account defined for the image"
grep -Fq 'getent group autologin | cut -d: -f4 | grep -q . || rm -f /etc/xdg/kwalletrc' \
  "$data_root/calamares/modules/shellprocess.conf" \
  || fail "an installed system with automatic login would ask to set up a wallet"

logo="$data_root/icons/kernora-logo.svg"
[[ -s "$logo" ]] || fail "logo master is missing"
grep -q 'viewBox=' "$logo" || fail "logo has no viewBox and cannot scale"
grep -q '<image' "$logo" && fail "logo embeds a raster image"
grep -Eq 'stroke="(?!none)' "$logo" 2>/dev/null && fail "logo uses strokes"

branding="$data_root/calamares/branding/kernora/branding.desc"
grep -Fq 'productName:         Kernora OS' "$branding" \
  || fail "installer branding does not name Kernora OS"
[[ -s "$data_root/calamares/branding/kernora/kernora-welcome.png" ]] \
  || fail "installer welcome image is missing"
grep -Fq 'productLogo:    "kernora-logo.png"' "$branding" \
  || fail "branding does not point at the generated logo"
PYTHONDONTWRITEBYTECODE=1 PYTHONPATH="$tools_root" python3 - "$branding" <<'PYTHON_TEST' \
  || fail "installer sidebar colours drifted from the design tokens"
import sys
import kernora_design as design
text = open(sys.argv[1], encoding="utf-8").read()
for key, role in (("SidebarBackground", "surfaceContainerLow"), ("SidebarText", "onSurfaceVariant"),
                  ("SidebarTextCurrent", "onPrimaryContainer"), ("SidebarBackgroundCurrent", "primaryContainer")):
    line = f'{key}:'.ljust(26) + f'"{design.DARK[role]}"'
    if line not in text:
        raise SystemExit(f"{key} is not {role}")
PYTHON_TEST

grep -Fq 'import org.kernora.shell' "$package_root/data/editmode/ConfigOverlay.qml" \
  && grep -Fq 'overlay.appletSettings.open(applet.plasmoid, overlay)' "$package_root/data/editmode/ConfigOverlay.qml" \
  || fail "a widget's settings end edit mode"

grep -Fq 'motionScale: Kirigami.Units.longDuration > 1 ? Kirigami.Units.longDuration / 200 : 0' "$package_root/tools/gen-qml-tokens" \
  && grep -Fq '!isFinite(x) || !isFinite(v)' "$package_root/data/shell/m3/MSpring.qml" \
  && ! grep -rFq 'Kirigami.Units.longDuration === 0' "$package_root/data/wallpaper" \
  || fail "Reduce motion breaks the shell"
grep -Fq 'function dismiss()' "$package_root/data/editmode/ConfigOverlay.qml" \
  && grep -Fq 'if (!appletsLayout.editMode)' "$package_root/data/editmode/ConfigOverlay.qml" \
  || fail "widget toolbars stay open outside edit mode"
grep -Fq 'readonly property real room:' "$package_root/data/widgets/weather/contents/ui/main.qml" \
  || fail "weather text overflows narrow shapes"
! grep -rFq 'filterByScreen: true' "$package_root/data/wallpaper" \
  && grep -Fq 'x >= screen.x && x < screen.x + screen.width' "$package_root/data/wallpaper/org.kernora.starfall/contents/ui/main.qml" \
  || fail "live wallpapers pause for windows on other screens"
grep -Fq 'coverRetry.restart()' "$package_root/data/widgets/media/contents/ui/main.qml" \
  && grep -Fq 'artRetry.restart()' "$package_root/data/shell/shade/contents/ui/MediaCard.qml" \
  || fail "album art is not retried"
grep -Fq 'function kernoraRecolor()' "$package_root/data/systemmonitor/main.qml" \
  && grep -Fq 'name="kernoraColorBase"' "$package_root/data/systemmonitor/main.xml" \
  && grep -Fq 'org.kde.plasma.systemmonitor/contents/ui/main.qml' "$package_root/debian/kernora-desktop.preinst" \
  && grep -Fq 'org.kde.plasma.systemmonitor/contents/config/main.xml' "$package_root/debian/kernora-desktop.postrm" \
  || fail "system monitor colours ignore the theme"
grep -Fq 'session.requestReboot()' "$package_root/data/shell/launcher/contents/ui/main.qml" \
  && grep -Fq 'if (maysd && (reboot || halt || showAllOptions))' "$package_root/data/look-and-feel/org.kernora.desktop/contents/logout/Logout.qml" \
  || fail "the power menu has no restart"
grep -Fq 'org.freedesktop.policykit.exec.path">/usr/libexec/kernora-greeter-background' "$package_root/data/greeter/org.kernora.greeter-background.policy" \
  && grep -Fq 'config.wallpaper' "$package_root/data/sddm-theme/kernora/Main.qml" \
  && grep -Fq 'readonly property bool ownBackground' "$package_root/data/lockscreen/LockScreen.qml" \
  && grep -Fxq 'WallpaperPlugin=org.kernora.shapes' "$package_root/data/xdg-kscreenlockerrc/kscreenlockerrc" \
  && grep -Fq '/usr/share/kernora/xdg:' "$package_root/data/plasma-env/kernora-config-dirs.sh" \
  || fail "lock and login screens ignore the wallpaper"

lockscreen="$package_root/data/lockscreen/LockScreen.qml"
grep -Fq 'MShapeEcho {' "$lockscreen" && grep -Fq 'echoMode: TextInput.NoEcho' "$lockscreen" \
  || fail "the lock screen still shows plain password dots"
[[ "$(grep -c 'M3.darkScheme' "$lockscreen")" -le 4 ]] || fail "the lock screen card ignores the light theme"
greeter_qml="$package_root/data/sddm-theme/kernora/Main.qml"
grep -Fq 'import org.kernora.m3' "$greeter_qml" && grep -Fq 'MShapeEcho {' "$greeter_qml" \
  && grep -Fq 'M3.colourOverride' "$greeter_qml" && ! grep -Fq 'palette.js' "$greeter_qml" \
  || fail "the login screen does not follow the synced colour and theme"
grep -Fq 'MShapeEcho MShapeEcho.qml' "$package_root/data/shell/m3/qmldir" || fail "MShapeEcho is not registered"
grep -Fq 'MLinearProgress {' "$package_root/data/ui/LinearProgress.qml" \
  && grep -Fq 'MCircularProgress {' "$package_root/data/style/org.kernora.desktop/BusyIndicator.qml" \
  && grep -Fq 'contentItem: MLinearProgress {' "$package_root/data/style/org.kernora.desktop/ProgressBar.qml" \
  || fail "progress bars and spinners are not the wavy expressive ones"
grep -Fq 'readonly property bool waving: wavy && !M3.classic' "$package_root/data/shell/m3/MLinearProgress.qml" \
  && grep -Fq 'shown > 0.1 && shown < 0.95' "$package_root/data/shell/m3/MLinearProgress.qml" \
  || fail "the wave does not flatten for md1/md2 or at the ends of the progress"
grep -Fq 'MLoadingIndicator MLoadingIndicator.qml' "$package_root/data/shell/m3/qmldir" \
  && grep -Fq 'gen-loading-shapes generated/style/org/kernora/m3/loadingshapes.js' "$package_root/debian/rules" \
  || fail "the shape morphing loading indicator is not built"
shapes_out=$(mktemp)
python3 "$package_root/tools/gen-loading-shapes" "$shapes_out"
python3 - "$shapes_out" <<'PY' || fail "loading shapes are not sampled the same way"
import json, re, sys
text = open(sys.argv[1]).read()
samples = int(re.search(r"var samples = (\d+);", text).group(1))
shapes = json.loads(re.search(r"var shapes = (.*);", text).group(1))
assert len(shapes) == 7 and all(len(s) == samples for s in shapes)
assert all(0.2 < r < 0.75 for s in shapes for r in s)
PY
rm -f "$shapes_out"
grep -Fq 'readonly property bool expressive: !M3.classic' "$package_root/data/ui/SegmentedButtons.qml" \
  && grep -Fq '(isFirst ? full : inner + (full - inner) * chosenMorph.value)' "$package_root/data/ui/SegmentedButtons.qml" \
  || fail "segmented buttons are not the connected expressive group"
grep -Fq 'MMorph { id: checkMorph; active: root.checked }' "$package_root/data/ui/IconButton.qml" \
  || fail "icon buttons do not change shape when pressed or checked"
grep -Fq 'MMorph MMorph.qml' "$package_root/data/shell/m3/qmldir" \
  && grep -Fq '"expressiveFast": (0.6, 0.222)' "$package_root/tools/kernora_design.py" \
  && grep -Fq 'MMorph { id: pressMorph; active: surface.control.down }' "$package_root/data/style/org.kernora.desktop/private/ButtonSurface.qml" \
  && grep -Fq 'MMorph { id: checkMorph; active: root.checkable && root.checked }' "$package_root/data/shell/m3/MIconButton.qml" \
  && grep -Fq 'MMorph { id: pressMorph; active: mouse.pressed }' "$package_root/data/shell/m3/MButton.qml" \
  || fail "buttons do not morph on the expressive springs"
grep -Fq 'height + (parent.width - height) * selectMorph.value' "$package_root/data/ui/NavigationItem.qml" \
  || fail "the navigation indicator does not grow out of the icon"
tokens_out=$(mktemp)
python3 "$package_root/tools/gen-qml-tokens" "$tokens_out" >/dev/null
grep -Fq 'readonly property font bodyLargeEmphasized: Qt.font({ family: tokens.typeface, pixelSize: Math.round(16 * tokens.scale), weight: [400, 400, 500][tokens.generationIndex]' "$tokens_out" \
  && grep -Fq 'readonly property int labelLargeEmphasizedLineHeight:' "$tokens_out" \
  && grep -Fq 'menu: [2, 4, 16]' "$tokens_out" \
  && grep -Fq 'role: root.current ? "bodyLargeEmphasized" : "bodyLarge"' "$package_root/data/ui/NavigationItem.qml" \
  || fail "there is no emphasized type for selected items"
rm -f "$tokens_out"
grep -Fq 'color: control.selected ? M3.tertiaryContainer' "$package_root/data/style/org.kernora.desktop/MenuItem.qml" \
  && grep -Fq 'radius: M3.classic ? 0 : 12' "$package_root/data/shell/m3/MMenu.qml" \
  && grep -Fxq 'MENU_RADIUS = 16' "$package_root/tools/gen-kvantum-theme" \
  || fail "menus are not the expressive ones"
for script in kernora-desktop.preinst kernora-desktop.postrm; do
  grep -q '^pickers=.*\bkcm_landingpage\b' "$package_root/debian/$script" \
    && grep -Fq 'systemsettings_qwidgets/kcm_kwintabbox.so' "$package_root/debian/$script" \
    && grep -Fq '"$tasks/ContextMenu.qml" "$tasks/Task.qml"' "$package_root/debian/$script" \
    || fail "the KDE landing page, task switcher picker or task menu are not replaced ($script)"
done
grep -Fq 'color: M3.inverseOnSurface' "$package_root/data/style/org.kernora.desktop/ToolTip.qml" \
  && grep -Fq 'color: M3.inverseSurface' "$package_root/data/style/org.kernora.desktop/ToolTip.qml" \
  || fail "tooltip text does not match the tooltip background"
! grep -Fq 'sourceComponent: busyIndicator' "$package_root/data/taskmanager/Task.qml" \
  && grep -Fq 'running: model.IsStartup && Kirigami.Units.longDuration > 1' "$package_root/data/taskmanager/Task.qml" \
  && grep -Fq 'NumberAnimation { target: icon; property: "scale"; to: 0.82;' "$package_root/data/taskmanager/Task.qml" \
  && grep -Fxq 'data/taskmanager/Task.qml usr/share/plasma/plasmoids/org.kde.plasma.taskmanager/contents/ui' "$package_root/debian/kernora-desktop.install" \
  && grep -Fxq 'Files: data/taskmanager/Task.qml' "$package_root/debian/copyright" \
  || fail "starting apps still get KDE's spinner on their dock icon"
grep -Fq 'i18nd("kernora-ui", "Unpin from panel")' "$package_root/data/taskmanager/ContextMenu.qml" \
  && ! grep -Fq 'internalAction("configure")' "$package_root/data/taskmanager/ContextMenu.qml" \
  && ! grep -Fq 'Task Manager' "$package_root/data/taskmanager/ContextMenu.qml" \
  && grep -Fxq 'data/taskmanager/ContextMenu.qml usr/share/plasma/plasmoids/org.kde.plasma.taskmanager/contents/ui' "$package_root/debian/kernora-desktop.install" \
  || fail "the task icon menu still talks about the KDE task manager"
grep -Fq 'delegate: WidgetCard {' "$package_root/data/explorer/WidgetExplorer.qml" \
  && grep -Fq 'sourceComponent: card.kernora ? kernoraPreview : otherPreview' "$package_root/data/explorer/WidgetCard.qml" \
  && grep -Fq 'cp data/explorer/*.qml data/explorer/*.js' "$package_root/debian/rules" \
  || fail "widgets from KDE are not shown as cards with Material previews"
grep -Fq 'i18nd("plasmashellprivateplugin", "Download New Plasma Widgets")' "$package_root/data/explorer/WidgetExplorer.qml" \
  && grep -Fq '.filter(action => !action.separator && action.text.length > 0 && action.text !== store)' "$package_root/data/explorer/WidgetExplorer.qml" \
  && grep -Fq 'readonly property real widestRow' "$package_root/data/shell/m3/MMenu.qml" \
  || fail "the widgets menu still offers the KDE store or clips its labels"
grep -Fq 'readonly property real handleX: track.level * (width - slot)' "$package_root/data/osd/KernoraOsdItem.qml" \
  || fail "the volume pop-up is not the expressive slider"
for wallpaper in shapes pastel rhythm starfall ribbon; do
  main="$package_root/data/wallpaper/org.kernora.$wallpaper/contents/ui/main.qml"
  grep -Fq 'readonly property bool lockScreen: typeof authenticator !== "undefined"' "$main" \
    && grep -Fq 'function phaseAt(time: double): real {' "$main" \
    && grep -Fq 'intro: root.switched ? 0 : 1' "$main" \
    && grep -Fq 'running: root.running && !root.lockScreen' "$main" \
    && grep -Fq '<entry name="IntroAt" type="String">' "$package_root/data/wallpaper/org.kernora.$wallpaper/contents/config/main.xml" \
    || fail "the $wallpaper wallpaper does not run on the clock or replays its intro at login"
done
for screen in lockscreen/LockScreen.qml sddm-theme/kernora/Main.qml; do
  grep -Fq 'revealSpring.jumpTo(Math.max(0, Math.min(1, ' "$package_root/data/$screen" \
    && grep -Fq 'onWheel: wheel => {' "$package_root/data/$screen" \
    && grep -Fq 'flick > 600 || (flick > -600 && ' "$package_root/data/$screen" \
    || fail "$screen has no swipe up"
done
grep -Fq '"lock_24px.svg": ("lock", "onSurface")' "$package_root/tools/gen-greeter-palette" \
  && grep -Fq 'msgid "Swipe up or start typing"' "$package_root/data/shell/po/kernora-ui.ru.po" \
  || fail "the swipe hint has no icon or translation"
grep -Fq 'leave.start();' "$package_root/data/sddm-theme/kernora/Main.qml" \
  && grep -Fq 'return (offset + Date.now() / 1000 / loop) % 1;' "$package_root/data/sddm-theme/kernora/Main.qml" \
  && grep -Fq 'onFinished: Qt.quit()' "$package_root/data/lockscreen/LockScreen.qml" \
  && ! grep -Fq 'Qt.quit();' "$package_root/data/lockscreen/LockScreen.qml" \
  || fail "login and lock screens do not slide away on success"
grep -Fxq 'data/greeter/kernora-splash-wallpaper usr/libexec' "$package_root/debian/kernora-desktop.install" \
  && grep -Fq '/usr/libexec/kernora-splash-wallpaper || true' "$package_root/data/greeter/kernora-greeter-background" \
  && grep -Fq '/usr/libexec/kernora-splash-wallpaper || true' "$package_root/debian/kernora-desktop.postinst" \
  && [[ -x "$package_root/data/greeter/kernora-splash-wallpaper" ]] \
  || fail "the splash does not learn which wallpaper to show"
grep -Fxq 'FloatingToolbar 1.0 FloatingToolbar.qml' "$package_root/data/ui/qmldir" \
  && grep -Fq 'checkedFill: M3.secondaryContainer' "$package_root/data/ui/IconButton.qml" \
  || fail "there is no floating toolbar"
for file in shell/shade/contents/ui/PanelRow.qml shell/shade/contents/ui/MediaCard.qml shell/launcher/contents/ui/LauncherButton.qml \
    lockscreen/LockScreen.qml lockscreen/KernoraMediaControls.qml look-and-feel/org.kernora.desktop/contents/logout/Logout.qml \
    calamares/branding/kernora/keyboardq.qml calamares/branding/kernora/finishedq.qml; do
  ! grep -Fq 'Behavior on radius' "$package_root/data/$file" && grep -Fq 'MMorph {' "$package_root/data/$file" \
    || fail "$file still changes shape on a plain curve"
done
for script in kernora-desktop.preinst kernora-desktop.postrm; do
  for module in kcm_lookandfeel kcm_desktoptheme kcm_colors kcm_style kcm_icons kcm_cursortheme \
      kcm_kwindecoration kcm_splashscreen kcm_sddm kcm_soundtheme; do
    grep -q "^pickers=.*\b$module\b" "$package_root/debian/$script" \
      || fail "$module can still bring the KDE look back ($script)"
  done
  grep -Fq '/usr/bin/lookandfeeltool /usr/bin/plasma-apply-lookandfeel' "$package_root/debian/$script" \
    && grep -Fq '/usr/bin/kvantummanager' "$package_root/debian/$script" \
    || fail "theme reset tools are still around ($script)"
done
grep -Fxq 'Exec=/usr/bin/kernora-installer --autostart' "$package_root/data/installer/org.kernora.installer-autostart.desktop" \
  && grep -Fxq 'data/installer/org.kernora.installer-autostart.desktop etc/xdg/autostart' "$package_root/debian/kernora-calamares.install" \
  && grep -Fq "grep -qw 'boot=live' /proc/cmdline" "$package_root/data/installer/kernora-installer" \
  || fail "the live session does not open the installer"
grep -Fxq 'Id=kernora_welcome_retired' "$package_root/data/kconf_update/kernora-welcome-retired.upd" \
  && grep -Fxq 'data/kconf_update/kernora-welcome-retired.sh usr/share/kconf_update' "$package_root/debian/kernora-desktop.install" \
  && [[ -x "$package_root/data/kconf_update/kernora-welcome-retired.sh" ]] \
  || fail "welcome stays in the menu after people went through it"
shade_ui="$package_root/data/shell/shade/contents/ui"
grep -Fq 'internet: internetTile' "$shade_ui/ShadeSheet.qml" && grep -Fq 'TileGrid {' "$shade_ui/ShadeSheet.qml" \
  && grep -Fq 'root.detail === "internet" ? internetPanel' "$shade_ui/ShadeSheet.qml" \
  && grep -Fq '"/kernora-quicksettingsrc"' "$shade_ui/TileGrid.qml" \
  && grep -Fq 'handler.addAndActivateConnection(entry.modelData.devicePath, entry.modelData.specificPath, password.text)' "$shade_ui/InternetPanel.qml" \
  && grep -Fq 'device.connectToDevice()' "$shade_ui/BluetoothPanel.qml" \
  && grep -Fq 'readonly property bool wiredConnected' "$shade_ui/sources/NetworkSource.qml" \
  || fail "quick settings are not the android style internet, bluetooth and editable tiles"
grep -Fq 'property bool compact: false' "$package_root/data/shell/m3/MTile.qml" \
  && grep -Fq 'readonly property bool split: hasDetails && !compact && available' "$package_root/data/shell/m3/MTile.qml" \
  || fail "tiles have no small or split form"
grep -Fq 'SessionGroup {' "$package_root/data/shell/launcher/contents/ui/LauncherView.qml" \
  && grep -Fq 'MMorph { id: pressMorph; active: mouse.pressed }' "$package_root/data/shell/launcher/contents/ui/AppTile.qml" \
  || fail "the launcher is not the expressive one"
grep -Fq 'msgid "Edit tiles"' "$package_root/data/shell/po/plasma_applet_org.kernora.quicksettings.ru.po" \
  && grep -Fq 'msgid "Pair new device"' "$package_root/data/shell/po/plasma_applet_org.kernora.quicksettings.ru.po" \
  || fail "the new quick settings are not translated"
grep -Fq 'root.backend.openSettings("appearance")' "$package_root/data/shell/shade/contents/ui/ShadeSheet.qml" \
  && ! grep -Fq 'kcm_lookandfeel' "$package_root/data/shell/shade/contents/ui/ShadeSheet.qml" \
  || fail "the dark theme tile still points at the KDE global theme"
grep -Fxq 'Id=kernora_sound_theme_without_ocean' "$package_root/data/kconf_update/kernora-sound-theme.upd" \
  || fail "ocean users are not moved to the Kernora sounds"
grep -Fq 'GRUB_THEME=/boot/grub/themes/kernora/theme.txt' "$package_root/data/grub/kernora.cfg" \
  && grep -Fq '/usr/libexec/kernora-grub-theme' "$package_root/data/grub/kernora.cfg" \
  && grep -Fq '/usr/libexec/kernora-grub-theme || true' "$package_root/data/greeter/kernora-greeter-background" \
  && grep -Fq '/usr/libexec/kernora-grub-theme || true' "$package_root/debian/kernora-desktop.postinst" \
  && grep -Fq 'generated/grub-themes/$$colour-$$mode $$mode' "$package_root/debian/rules" \
  || fail "the boot menu does not follow the colour and theme"
grep -Fq '/usr/libexec/kernora-boot-theme --initramfs || true' "$package_root/data/greeter/kernora-greeter-background" \
  && grep -Fq '/usr/libexec/kernora-boot-theme || true' "$package_root/debian/kernora-desktop.postinst" \
  && grep -Fq 'gen-plymouth-theme --masks' "$package_root/debian/rules" \
  && grep -Fq 'pack-boot-masks generated/plymouth-masks generated/boot/plymouth.pack' "$package_root/debian/rules" \
  || fail "the boot splash does not follow the colour and theme"
python3 -I -m py_compile "$package_root/data/plymouth/kernora-boot-theme" 2>/dev/null \
  || fail "the boot theme tool does not compile"
find "$package_root/data/plymouth" -name __pycache__ -exec rm -rf {} +
bash -n "$package_root/data/grub/kernora-grub-theme" || fail "the grub theme helper does not parse"
! grep -qi 'ember' "$package_root/data/calamares/branding/kernora/branding.desc" \
  || fail "the installer still says Ember"
grep -Fq '/^[0-9.]+$/.test(version) ? ["", ""] : ["«", "»"]' "$package_root/data/calamares/branding/kernora/welcomeq.qml" \
  || fail "the installer puts quotes around a plain version number"
grep -Fq 'source: parent.user ? parent.user.picture : ""' "$greeter_qml" \
  && ! grep -Fq '"file://" + parent.user.picture' "$greeter_qml" \
  || fail "the login screen breaks the avatar url sddm already gives it"
tokens_out=$(mktemp)
python3 "$package_root/tools/gen-qml-tokens" "$tokens_out" >/dev/null
grep -Fq 'tokens.darkOverride !== null ? tokens.darkOverride : tokens.schemeDark' "$tokens_out" \
  && grep -Fq '"/kdeglobals"' "$tokens_out" && grep -Fq '"/kdedefaults/kdeglobals"' "$tokens_out" \
  || fail "M3 does not read light or dark from the colour scheme"
rm -f "$tokens_out"
helper="$package_root/data/greeter/kernora-greeter-background"
grep -Fq 'colour=%s' "$helper" && grep -Fq 'mode=%s' "$helper" || fail "the greeter helper does not record colour and mode"
plymouth_out=$(mktemp -d)
(cd "$package_root/tools" && python3 gen-plymouth-theme ../data/icons/kernora-logo.svg ../data/symbols "$plymouth_out") >/dev/null
[[ -s "$plymouth_out/wave-0.svg" && -s "$plymouth_out/wave-89.svg" && ! -e "$plymouth_out/bullet.svg" ]] \
  && grep -Fq 'waves[tick % wave_count]' "$plymouth_out/kernora.script" \
  || fail "the boot splash has no wavy indicator"
rm -rf "$plymouth_out"
grep -Fq 'generated/faces/*.png usr/share/kernora/faces' "$package_root/debian/kernora-desktop.install" \
  || fail "the Kernora face is not built in every colour"

printf 'kernora-desktop source test: OK\n'
