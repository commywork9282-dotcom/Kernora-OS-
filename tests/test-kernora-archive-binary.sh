#!/usr/bin/env bash
set -Eeuo pipefail

project_root=$(CDPATH= cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)
package_root="$project_root/packages/native/kernora-archive"
package_version=$(dpkg-parsechangelog -l"$package_root/debian/changelog" -S Version)
deb="$project_root/_build/binary-packages/kernora-archive_${package_version}_all.deb"

fail() {
  printf 'kernora-archive binary test: %s\n' "$*" >&2
  exit 1
}

[[ -s "$deb" ]] || fail "binary package does not exist"
[[ "$(dpkg-deb --field "$deb" Package)" == "kernora-archive" ]] || fail "wrong package name"
[[ "$(dpkg-deb --field "$deb" Version)" == "$package_version" ]] || fail "wrong package version"
[[ "$(dpkg-deb --field "$deb" Architecture)" == "all" ]] || fail "wrong package architecture"

temporary_root=$(mktemp -d /tmp/kernora-archive-test.XXXXXX)
trap 'find "$temporary_root" -depth -delete' EXIT
dpkg-deb --extract "$deb" "$temporary_root/root"
dpkg-deb --control "$deb" "$temporary_root/control"
for path in \
  usr/share/keyrings/kernora-archive-keyring.asc \
  etc/apt/sources.list.d/debian.sources \
  etc/apt/sources.list.d/kernora.sources \
  etc/apt/preferences.d/kernora-archive.pref \
  etc/apt/apt.conf.d/21kernora-auto-upgrades \
  etc/apt/apt.conf.d/51kernora-unattended-upgrades \
  usr/lib/systemd/system/apt-daily.timer.d/kernora-live.conf \
  usr/lib/systemd/system/apt-daily-upgrade.timer.d/kernora-live.conf; do
  [[ -s "$temporary_root/root/$path" ]] || fail "missing $path"
done
for conffile in \
  /etc/apt/sources.list.d/debian.sources \
  /etc/apt/sources.list.d/kernora.sources \
  /etc/apt/preferences.d/kernora-archive.pref \
  /etc/apt/apt.conf.d/21kernora-auto-upgrades \
  /etc/apt/apt.conf.d/51kernora-unattended-upgrades; do
  grep -Fxq "$conffile" "$temporary_root/control/conffiles" || fail "$conffile is not a conffile"
done

printf 'kernora-archive binary test: OK\n'
