#!/bin/sh
config=${XDG_CONFIG_HOME:-$HOME/.config}
globals="$config/kdeglobals"
if [ -f "$globals" ]; then
  current=$(sed -n '/^\[Sounds\]/,/^\[/s/^Theme=//p' "$globals" | head -n 1)
  if [ "$current" = ocean ]; then
    sed -i '/^\[Sounds\]/,/^\[/s/^Theme=ocean$/Theme=kernora/' "$globals"
  fi
fi
for version in 3.0 4.0; do
  ini="$config/gtk-$version/settings.ini"
  [ -f "$ini" ] || continue
  if grep -q '^gtk-sound-theme-name=ocean$' "$ini"; then
    sed -i 's/^gtk-sound-theme-name=ocean$/gtk-sound-theme-name=kernora/' "$ini"
  elif ! grep -q '^gtk-sound-theme-name=' "$ini" && grep -q '^\[Settings\]' "$ini"; then
    sed -i '/^\[Settings\]/a gtk-sound-theme-name=kernora' "$ini"
  fi
done
current=$(gsettings get org.gnome.desktop.sound theme-name 2>/dev/null)
case $current in
  "'ocean'"|"'freedesktop'"|'') gsettings set org.gnome.desktop.sound theme-name kernora 2>/dev/null ;;
esac
exit 0
