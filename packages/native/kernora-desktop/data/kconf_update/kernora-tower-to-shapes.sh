#!/bin/sh
file="${XDG_CONFIG_HOME:-$HOME/.config}/kscreenlockerrc"
if [ -f "$file" ] && grep -q 'org\.kernora\.tower' "$file"; then
  sed -i 's/^\([Ww]allpaper[Pp]lugin=\)org\.kernora\.tower$/\1org.kernora.shapes/' "$file"
fi
exit 0
