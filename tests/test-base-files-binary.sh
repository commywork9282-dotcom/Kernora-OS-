#!/usr/bin/env bash
set -Eeuo pipefail

project_root=$(CDPATH= cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)
package_root="$project_root/packages/derived/base-files"
package_version=$(dpkg-parsechangelog -l"$package_root/debian/changelog" -S Version)
deb="$project_root/_build/binary-packages/base-files_${package_version}_amd64.deb"

fail() {
  printf 'base-files binary test: %s\n' "$*" >&2
  exit 1
}

[[ -s "$deb" ]] || fail "binary package does not exist"
[[ "$(dpkg-deb --field "$deb" Package)" == "base-files" ]] || fail "wrong package name"
[[ "$(dpkg-deb --field "$deb" Version)" == "$package_version" ]] || fail "wrong package version"

temporary_root=$(mktemp -d /tmp/kernora-base-files-test.XXXXXX)
trap 'find "$temporary_root" -depth -delete' EXIT
installed_root="$temporary_root/root"
control_root="$temporary_root/control"
dpkg-deb --extract "$deb" "$installed_root"
dpkg-deb --control "$deb" "$control_root"

[[ "$(readlink "$installed_root/etc/os-release")" == "../usr/lib/os-release" ]] \
  || fail "os-release link is not relative"
grep -Fxq 'ID=kernora' "$installed_root/usr/lib/os-release" \
  || fail "installed os-release has the wrong ID"
grep -Fxq 'VERSION_CODENAME=ember' "$installed_root/usr/lib/os-release" \
  || fail "installed os-release has the wrong codename"
grep -Fxq 'Vendor: Kernora' "$installed_root/etc/dpkg/origins/kernora" \
  || fail "installed vendor origin is missing"
grep -Fxq 'Parent: Debian' "$installed_root/etc/dpkg/origins/kernora" \
  || fail "installed parent origin is missing"

ln -s debian "$installed_root/etc/dpkg/origins/default"
DPKG_ROOT="$installed_root" sh "$control_root/postinst" noop
[[ "$(readlink "$installed_root/etc/dpkg/origins/default")" == "kernora" ]] \
  || fail "postinst did not migrate the default vendor"

printf 'base-files binary test: OK\n'
