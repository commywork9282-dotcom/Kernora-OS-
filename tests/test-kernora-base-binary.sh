#!/usr/bin/env bash
set -Eeuo pipefail

project_root=$(CDPATH= cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)
package_root="$project_root/packages/native/kernora-base"
package_version=$(dpkg-parsechangelog -l"$package_root/debian/changelog" -S Version)
deb="$project_root/_build/binary-packages/kernora-base_${package_version}_all.deb"

fail() {
  printf 'kernora-base binary test: %s\n' "$*" >&2
  exit 1
}

for dependency in dpkg-deb find grep; do
  command -v "$dependency" >/dev/null 2>&1 \
    || fail "required command not found: $dependency"
done

[[ -s "$deb" ]] || fail "binary package does not exist"
[[ "$(dpkg-deb --field "$deb" Package)" == "kernora-base" ]] \
  || fail "wrong package name"
[[ "$(dpkg-deb --field "$deb" Version)" == "$package_version" ]] \
  || fail "wrong package version"
[[ "$(dpkg-deb --field "$deb" Architecture)" == "all" ]] \
  || fail "wrong package architecture"
[[ "$(dpkg-deb --field "$deb" Section)" == "metapackages" ]] \
  || fail "wrong package section"
depends=$(dpkg-deb --field "$deb" Depends)
[[ "$depends" == "base-files (= 13.8+deb13u6+kernora1), kernora-archive (>= 1.0)" ]] \
  || fail "wrong binary dependency: $depends"
essential=$(dpkg-deb --field "$deb" Essential)
[[ "$essential" == "no" || -z "$essential" ]] \
  || fail "metapackage must not be Essential"

temporary_root=$(mktemp -d /tmp/kernora-base-test.XXXXXX)
trap 'find "$temporary_root" -depth -delete' EXIT
dpkg-deb --extract "$deb" "$temporary_root/root"
if find "$temporary_root/root" -type f \
  ! -path "$temporary_root/root/usr/share/doc/kernora-base/*" \
  -print -quit | grep -q .; then
  fail "metapackage contains a file outside its documentation directory"
fi

printf 'kernora-base binary test: OK\n'
