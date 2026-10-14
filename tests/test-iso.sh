#!/usr/bin/env bash
set -Eeuo pipefail

project_root=$(CDPATH= cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)
iso=${1:-}

fail() {
  printf 'ISO test: %s\n' "$*" >&2
  exit 1
}

[[ -n "$iso" && -s "$iso" ]] || fail "ISO file was not provided"
for dependency in grep mktemp unsquashfs xorriso; do
  command -v "$dependency" >/dev/null 2>&1 \
    || fail "required command not found: $dependency"
done

# shellcheck disable=SC1091
source "$project_root/configs/live/live-user.env"
live_user=$LIVE_USER
live_uid=$LIVE_USER_UID

temporary_root=$(mktemp -d /tmp/kernora-iso-test.XXXXXX)
trap 'find "$temporary_root" -depth -delete' EXIT

xorriso -indev "$iso" -report_el_torito plain \
  > "$temporary_root/el-torito.txt" 2>&1
grep -Eq 'BIOS.*boot image|boot img.*BIOS' "$temporary_root/el-torito.txt" \
  || fail "BIOS El Torito entry is missing"
grep -Eq 'UEFI.*boot image|boot img.*UEFI' "$temporary_root/el-torito.txt" \
  || fail "UEFI El Torito entry is missing"

xorriso -indev "$iso" -report_system_area plain \
  > "$temporary_root/system-area.txt" 2>&1
grep -Fq 'grub2-mbr' "$temporary_root/system-area.txt" \
  || fail "GRUB2 hybrid system area is missing"

for path in \
  /boot/grub/grub.cfg \
  /boot/grub/themes/kernora/theme.txt \
  /boot/grub/themes/kernora/roboto-regular-16.pf2 \
  /boot/grub/themes/kernora/select_c.png \
  /live/vmlinuz \
  /live/initrd.img \
  /live/filesystem.squashfs \
  /live/filesystem.packages \
  /.disk/info; do
  xorriso -indev "$iso" -find "$path" -type f -- \
    > "$temporary_root/find.txt" 2>&1
  grep -Fq "$path" "$temporary_root/find.txt" || fail "missing ISO path: $path"
done

xorriso -osirrox on -indev "$iso" \
  -extract /boot/grub/grub.cfg "$temporary_root/grub.cfg" \
  > "$temporary_root/extract-grub.txt" 2>&1
awk '/usr\/share\/kernora\/settings\/Main.qml/ && !found { found = NR } /^menuentry .*--id live-en/ { live = NR }
     END { exit !(found && live && found < live) }' "$temporary_root/grub.cfg" \
  || fail "the ISO menu does not start an installed Kernora before the live session"
grep -Fxq 'set default=live-en' "$temporary_root/grub.cfg" \
  || fail "the default live session is not English"
awk '/^menuentry .*--id live-/ { exit !($0 ~ /--id live-en/) }' "$temporary_root/grub.cfg" \
  || fail "English is not the first live entry"
grep -Fq 'menuentry "Kernora OS · Русский" --id live-ru {' "$temporary_root/grub.cfg" \
  || fail "the Russian live session is missing"
grep -Fq '    set default=installed' "$temporary_root/grub.cfg" \
  || fail "an installed system no longer takes boot priority"
[[ "$(grep -c ' quiet loglevel=3 splash ' "$temporary_root/grub.cfg")" == 2 ]] \
  || fail "the live session prints kernel errors over the boot splash"

xorriso -osirrox on -indev "$iso" \
  -extract /live/filesystem.squashfs "$temporary_root/filesystem.squashfs" \
  > "$temporary_root/extract.txt" 2>&1
unsquashfs -lln "$temporary_root/filesystem.squashfs" \
  > "$temporary_root/inodes.txt"
awk '$NF == "squashfs-root" { found = 1; if ($1 != "drwxr-xr-x" || $2 != "0/0") exit 1 }
     END { if (!found) exit 1 }' "$temporary_root/inodes.txt" \
  || fail "SquashFS root must be root:root with mode 0755"

unsquashfs -cat "$temporary_root/filesystem.squashfs" usr/lib/os-release \
  > "$temporary_root/os-release"
grep -Fxq 'ID=kernora' "$temporary_root/os-release" \
  || fail "SquashFS has the wrong OS identity"
unsquashfs -cat "$temporary_root/filesystem.squashfs" \
  etc/systemd/system/kernora-boot-ready.service \
  > "$temporary_root/boot-ready.service"
grep -Fq 'KERNORA_BOOT_OK' "$temporary_root/boot-ready.service" \
  || fail "boot readiness marker is absent"

xorriso -osirrox on -indev "$iso" \
  -extract /live/filesystem.packages "$temporary_root/filesystem.packages" \
  > "$temporary_root/extract-packages.txt" 2>&1
while read -r package; do
  [[ -n "$package" && "$package" != \#* ]] || continue
  if awk -v package="$package" '
    $1 == package || index($1, package ":") == 1 { found = 1 }
    END { exit !found }
  ' "$temporary_root/filesystem.packages"; then
    fail "ISO contains excluded KDE application: $package"
  fi
done < "$project_root/configs/live/excluded-packages.txt"

unsquashfs -lln "$temporary_root/filesystem.squashfs" "/home/$live_user" \
  > "$temporary_root/home.txt" 2>&1
grep -E "[[:space:]]$live_uid/$live_uid[[:space:]]" "$temporary_root/home.txt" \
  | grep -Fq "home/$live_user" \
  || fail "live home is not owned by the live account in the SquashFS"

printf 'ISO static test: OK\n'
