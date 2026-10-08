#!/usr/bin/env bash
set -Eeuo pipefail

work=$(mktemp -d)
trap 'rm -rf -- "$work"' EXIT
mkdir -p "$work/input/home/live"
tar --numeric-owner --owner=0 --group=0 --no-recursion \
  -C "$work/input" -cf "$work/root.tar" . home
tar --numeric-owner --owner=1000 --group=1000 -C "$work/input" \
  -rf "$work/root.tar" home/live
env -u SOURCE_DATE_EPOCH mksquashfs - "$work/root.squashfs" \
  -tar -numeric-owner -default-uid 0 -default-gid 0 \
  -root-uid 0 -root-gid 0 -root-mode 0755 \
  -noappend -no-progress < "$work/root.tar" > "$work/build.log"
unsquashfs -lln "$work/root.squashfs" > "$work/inodes.txt"
awk '$NF == "squashfs-root" { root = ($1 == "drwxr-xr-x" && $2 == "0/0") }
     $NF == "squashfs-root/home/live" { live = ($2 == "1000/1000") }
     END { exit !(root && live) }' "$work/inodes.txt"
printf 'SquashFS root ownership test: OK\n'
