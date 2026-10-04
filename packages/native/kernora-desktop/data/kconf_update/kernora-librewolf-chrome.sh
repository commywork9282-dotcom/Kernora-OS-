#!/bin/sh
sheet=/usr/share/kernora/librewolf/userChrome.css
install=6C4726F70D182CF7
root=${XDG_CONFIG_HOME:-$HOME/.config}/librewolf/librewolf
[ -r "$sheet" ] || exit 0
if [ ! -e "$root/profiles.ini" ] && [ ! -e "$HOME/.librewolf" ]; then
  mkdir -p "$root/kernora.default-default"
  printf '[General]\nStartWithLastProfile=1\nVersion=2\n\n[Profile0]\nName=default-default\nIsRelative=1\nPath=kernora.default-default\nDefault=1\n\n[Install%s]\nDefault=kernora.default-default\nLocked=1\n' \
    "$install" > "$root/profiles.ini"
  printf '[%s]\nDefault=kernora.default-default\nLocked=1\n' "$install" > "$root/installs.ini"
fi
for ini in "$root/profiles.ini" "$HOME/.librewolf/profiles.ini"; do
  [ -r "$ini" ] || continue
  sed -n 's/^Path=//p' "$ini" | while IFS= read -r path; do
    case $path in
      /*) profile=$path ;;
      *) profile=${ini%/profiles.ini}/$path ;;
    esac
    [ -d "$profile" ] || continue
    if [ -e "$profile/chrome/userChrome.css" ] || [ -L "$profile/chrome/userChrome.css" ]; then
      continue
    fi
    mkdir -p "$profile/chrome"
    ln -s "$sheet" "$profile/chrome/userChrome.css"
  done
done
exit 0
