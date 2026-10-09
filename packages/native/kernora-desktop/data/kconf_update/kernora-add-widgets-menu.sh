#!/bin/sh
config=${XDG_CONFIG_HOME:-$HOME/.config}
file="$config/plasma-org.kde.plasma.desktop-appletsrc"
group='[ActionPlugins][0][RightButton;NoModifier]'
if [ -f "$file" ] && grep -Fxq "$group" "$file"; then
  exit 0
fi
mkdir -p "$config"
printf '\n%s\nadd widgets=true\n' "$group" >> "$file"
exit 0
