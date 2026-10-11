#!/bin/sh
config=${XDG_CONFIG_HOME:-$HOME/.config}
file="$config/plasma-org.kde.plasma.desktop-appletsrc"
group='[ActionPlugins][0][RightButton;NoModifier]'
mkdir -p "$config"
if ! { [ -f "$file" ] && grep -Fxq '[ActionPlugins][0]' "$file"; }; then
  printf '\n[ActionPlugins][0]\nRightButton;NoModifier=org.kde.contextmenu\n' >> "$file"
fi
if ! grep -Fxq "$group" "$file"; then
  printf '\n%s\nadd widgets=true\n' "$group" >> "$file"
fi
exit 0
