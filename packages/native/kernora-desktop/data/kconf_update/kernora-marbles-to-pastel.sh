#!/bin/sh
file="${XDG_CONFIG_HOME:-$HOME/.config}/kscreenlockerrc"
if [ -f "$file" ] && grep -q 'org\.kernora\.marbles' "$file"; then
  sed -i 's/^\([Ww]allpaper[Pp]lugin=\)org\.kernora\.marbles$/\1org.kernora.pastel/' "$file"
fi
exit 0
