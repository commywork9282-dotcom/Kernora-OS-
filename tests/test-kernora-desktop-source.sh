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
[[ "$version" == "1.4" ]] || fail "unexpected source version"
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
for wallpaper in shapes tower rhythm marbles; do
  for file in metadata.json contents/ui/main.qml contents/ui/Scene.qml contents/ui/config.qml contents/config/main.xml; do
    [[ -s "$data_root/wallpaper/org.kernora.$wallpaper/$file" ]] \
      || fail "the $wallpaper wallpaper lacks $file"
  done
  [[ -s "$package_root/data/shell/po/plasma_wallpaper_org.kernora.$wallpaper.ru.po" ]] \
    || fail "the $wallpaper wallpaper has no Russian translation"
done
[[ -s "$data_root/wallpaper/org.kernora.tower/contents/ui/tower.js" ]] || fail "the tower's simulation is missing"
[[ -s "$data_root/wallpaper/org.kernora.marbles/contents/ui/run.js" ]] || fail "the marble run's simulation is missing"
assets=$(mktemp -d)
python3 "$package_root/tools/gen-wallpaper-assets" "$assets" tower >/dev/null \
  || fail "gen-wallpaper-assets cannot write the tower's assets"
grep -q '"hull":\[\[' "$assets/materialshapes.js" || fail "the shapes have no hulls"
grep -q '"paper"' "$assets/palette.js" || fail "the tower's palette has no paper"
rm -rf "$assets"
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
grep -Fxq 'ColorScheme=KernoraDark' "$defaults" \
  || fail "look-and-feel does not select the Kernora colour scheme"
grep -Fxq 'name=kernora' "$defaults" \
  || fail "look-and-feel does not select the Kernora Plasma theme"

tools_root="$package_root/tools"
for tool in gen-color-schemes gen-icon-theme gen-kdeglobals gen-plasma-theme \
  gen-qml-tokens gen-translations fetch-symbols gen-wallpaper-assets \
  gen-kvantum-theme gen-aurorae-theme gen-avatar gen-terminal-theme gen-greeter-palette \
  gen-keyboard-maps gen-qm gen-installer-icons gen-installer-style gen-browser-theme gen-plymouth-theme gen-grub-theme gen-emoji-data; do
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
grep -Fq 'Inherits=breeze-dark,breeze,hicolor' "$tools_root/gen-icon-theme" \
  || fail "icon theme does not inherit Breeze and would lose every other icon"
grep -Fq 'LookAndFeelPackage=org.kernora.desktop' "$tools_root/gen-kdeglobals" \
  || fail "Kernora look-and-feel is not the system default"
PYTHONDONTWRITEBYTECODE=1 python3 "$tools_root/fetch-symbols" --check >/dev/null \
  || fail "vendored Material Symbols do not match data/symbols.lock"
[[ -s "$data_root/symbols/LICENSE" ]] || fail "Material Symbols licence is missing"

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
grep -Fq 'images/kernora.png' "$splash" \
  || fail "splash does not draw the Kernora mark"
if grep '^import' "$splash" | grep -qv '^import QtQuick$'; then
  fail "splash imports something other than QtQuick"
fi
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

printf 'kernora-desktop source test: OK\n'
