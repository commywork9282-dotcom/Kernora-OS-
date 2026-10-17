#!/bin/sh
config=${XDG_CONFIG_HOME:-$HOME/.config}
data=${XDG_DATA_HOME:-$HOME/.local/share}
entry="$data/applications/org.kernora.welcome.desktop"
if grep -q '^ShowOnLogin=false' "$config/kernora-welcomerc" 2>/dev/null && [ ! -e "$entry" ]; then
  mkdir -p "$data/applications"
  printf '[Desktop Entry]\nType=Application\nName=Welcome\nIcon=org.kernora.welcome\nExec=kernora-welcome\nNoDisplay=true\n' > "$entry"
fi
exit 0
