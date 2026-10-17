#!/usr/bin/env bash
set -Eeuo pipefail

project_root=$(CDPATH= cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)
rootfs=${1:-}

fail() {
  printf 'minimal rootfs test: %s\n' "$*" >&2
  exit 1
}

[[ -n "$rootfs" && -d "$rootfs" ]] || fail "rootfs directory was not provided"
command -v unshare >/dev/null 2>&1 || fail "required command not found: unshare"

unshare --map-auto --setuid 0 --setgid 0 chroot "$rootfs" /bin/bash -s <<'ROOTFS_TEST'
set -Eeuo pipefail

fail() {
  printf 'inside rootfs: %s\n' "$*" >&2
  exit 1
}

grep -Fxq 'ID=kernora' /usr/lib/os-release || fail "wrong operating-system ID"
grep -Fxq 'VERSION_CODENAME=ember' /usr/lib/os-release \
  || fail "wrong operating-system codename"
[[ "$(readlink /etc/os-release)" == "../usr/lib/os-release" ]] \
  || fail "os-release link is not relative"
grep -Fxq 'Vendor: Kernora' /etc/dpkg/origins/kernora \
  || fail "Kernora dpkg vendor is missing"
grep -Fxq 'Parent: Debian' /etc/dpkg/origins/kernora \
  || fail "Debian parent relationship is missing"
[[ "$(readlink /etc/dpkg/origins/default)" == "kernora" ]] \
  || fail "Kernora is not the default dpkg vendor"

[[ "$(dpkg-query -W -f='${Version}' base-files)" \
  == "13.8+deb13u7+kernora2" ]] || fail "wrong base-files version"
[[ "$(dpkg-query -W -f='${Version}' kernora-base)" == "1.4" ]] \
  || fail "kernora-base is not installed"

grep -Fq 'signed-by=/usr/share/keyrings/kernora-development-archive-keyring.gpg' \
  /etc/apt/sources.list || fail "Kernora source is not scoped to its key"
grep -Fq 'snapshot.debian.org/archive/debian/20261015T000000Z' \
  /etc/apt/sources.list || fail "Debian source is not pinned to the snapshot"
[[ ! -e /etc/apt/apt.conf.d/99mmdebstrap ]] \
  || fail "temporary mmdebstrap APT configuration remains"

archive=/usr/share/kernora/archive
[[ -s /usr/share/keyrings/kernora-development-archive-keyring.gpg ]] \
  || fail "Kernora archive key is missing"
[[ -s "$archive/dists/ember/InRelease" ]] \
  || fail "embedded Kernora InRelease is missing"

apt_root=$(mktemp -d /tmp/kernora-apt-test.XXXXXX)
chmod 0755 "$apt_root"
trap 'find "$apt_root" -depth -delete' EXIT
mkdir -p "$apt_root/etc/sources.list.d" \
  "$apt_root/state/lists/partial" "$apt_root/cache/archives/partial"
printf '%s\n' \
  'deb [signed-by=/usr/share/keyrings/kernora-development-archive-keyring.gpg] file:/usr/share/kernora/archive ember main' \
  > "$apt_root/etc/sources.list"
apt_options=(
  -o "Dir::Etc::sourcelist=$apt_root/etc/sources.list"
  -o "Dir::Etc::sourceparts=$apt_root/etc/sources.list.d"
  -o "Dir::State=$apt_root/state"
  -o 'Dir::State::status=/var/lib/dpkg/status'
  -o "Dir::Cache=$apt_root/cache"
  -o 'APT::Get::List-Cleanup=0'
  -o 'Acquire::Languages=none'
)
apt-get "${apt_options[@]}" update >/dev/null \
  || fail "APT rejected the embedded Kernora archive"
apt-cache "${apt_options[@]}" show kernora-base > "$apt_root/kernora-base.txt"
grep -Fxq 'Depends: base-files (= 13.8+deb13u7+kernora2), kernora-archive (>= 1.0)' \
  "$apt_root/kernora-base.txt" || fail "APT sees the wrong identity dependency"

printf 'inside rootfs: OK\n'
ROOTFS_TEST

printf 'minimal rootfs test: OK\n'
