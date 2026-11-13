#!/bin/sh
config=${XDG_CONFIG_HOME:-$HOME/.config}
generation=$(sed -n 's/^generation=//p' "$config/kernorarc" 2>/dev/null | head -n 1)
case $generation in
  md1|md2) exit 0 ;;
esac
if [ -f "$config/kdeglobals" ]; then
  sed -i -E 's/^(font|menuFont|toolBarFont|smallestReadableFont|activeFont)=Roboto,/\1=Google Sans Flex,/' "$config/kdeglobals"
fi
for ini in "$config/gtk-3.0/settings.ini" "$config/gtk-4.0/settings.ini"; do
  if [ -f "$ini" ]; then
    sed -i -E 's/^gtk-font-name=Roboto,/gtk-font-name=Google Sans Flex,/' "$ini"
  fi
done
if [ -f "$config/xsettingsd/xsettingsd.conf" ]; then
  sed -i -E 's/^Gtk\/FontName "Roboto,/Gtk\/FontName "Google Sans Flex,/' "$config/xsettingsd/xsettingsd.conf"
fi
current=$(gsettings get org.gnome.desktop.interface font-name 2>/dev/null)
case $current in
  "'Roboto,"*)
    size=${current#\'Roboto,}
    gsettings set org.gnome.desktop.interface font-name "Google Sans Flex,${size%\'}" 2>/dev/null
    ;;
esac
exit 0
