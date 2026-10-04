#!/bin/sh
config=${XDG_CONFIG_HOME:-$HOME/.config}
generation=$(sed -n 's/^generation=//p' "$config/kernorarc" 2>/dev/null | head -n 1)
case $generation in
  md1) theme=KernoraMD1 ;;
  md2) theme=KernoraMD2 ;;
  *) theme=Kernora ;;
esac
for version in 3.0 4.0; do
  ini="$config/gtk-$version/settings.ini"
  current=$(sed -n 's/^gtk-theme-name=//p' "$ini" 2>/dev/null | head -n 1)
  case $current in
    ''|Breeze|Breeze-Dark) ;;
    *) continue ;;
  esac
  mkdir -p "$config/gtk-$version"
  if grep -q '^gtk-theme-name=' "$ini" 2>/dev/null; then
    sed -i "s/^gtk-theme-name=.*/gtk-theme-name=$theme/" "$ini"
  elif grep -q '^\[Settings\]' "$ini" 2>/dev/null; then
    sed -i "/^\[Settings\]/a gtk-theme-name=$theme" "$ini"
  else
    printf '[Settings]\ngtk-theme-name=%s\n' "$theme" >> "$ini"
  fi
done
current=$(gsettings get org.gnome.desktop.interface gtk-theme 2>/dev/null)
case $current in
  "'Breeze'"|"'Breeze-Dark'"|"'Adwaita'"|'') gsettings set org.gnome.desktop.interface gtk-theme "$theme" 2>/dev/null ;;
esac
exit 0
