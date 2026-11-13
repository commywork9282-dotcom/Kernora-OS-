#!/usr/bin/env bash
set -Eeuo pipefail

project_root=$(CDPATH= cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)
package_root="$project_root/packages/native/kwin-effect-rounded-corners"
# shellcheck disable=SC1091
source "$project_root/configs/upstream/base.env"
package_version=$(dpkg-parsechangelog -l"$package_root/debian/changelog" -S Version)
deb="$project_root/_build/binary-packages/kwin-effect-rounded-corners_${package_version}_${BASE_ARCH}.deb"

fail() {
  printf 'kwin-effect-rounded-corners binary test: %s\n' "$*" >&2
  exit 1
}

[[ -s "$deb" ]] || fail "binary package does not exist"
[[ "$(dpkg-deb --field "$deb" Package)" == "kwin-effect-rounded-corners" ]] || fail "wrong package name"
[[ "$(dpkg-deb --field "$deb" Version)" == "$package_version" ]] || fail "wrong package version"
dpkg-deb --field "$deb" Depends | grep -Fq 'kwin-common (>= 4:6.3.6)' || fail "does not depend on KWin 6.3.6"

temporary_root=$(mktemp -d /tmp/kwin-effect-rounded-corners-test.XXXXXX)
trap 'find "$temporary_root" -depth -delete' EXIT
dpkg-deb --extract "$deb" "$temporary_root/root"
plugin=$(find "$temporary_root/root/usr/lib" -path '*/kwin/effects/plugins/kwin4_effect_shapecorners.so' -print -quit)
[[ -n "$plugin" && -s "$plugin" ]] || fail "the KWin effect plugin is missing"
[[ -s "$temporary_root/root/usr/share/doc/kwin-effect-rounded-corners/copyright" ]] || fail "copyright is missing"

printf 'kwin-effect-rounded-corners binary test: OK\n'
