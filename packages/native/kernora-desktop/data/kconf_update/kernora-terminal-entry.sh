#!/bin/sh
entry="${XDG_DATA_HOME:-$HOME/.local/share}/applications/Alacritty.desktop"
skel=/etc/skel/.local/share/applications/Alacritty.desktop
if [ -f "$entry" ] && [ -f "$skel" ] && grep -qx 'NoDisplay=true' "$entry" && ! grep -q '^Icon=' "$entry"; then
  cp "$skel" "$entry"
fi
exit 0
