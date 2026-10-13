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

for dependency in cmp dpkg-deb find grep; do
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
[[ "$(dpkg-deb --field "$deb" Section)" == "admin" ]] \
  || fail "wrong package section"
depends=$(dpkg-deb --field "$deb" Depends)
[[ "$depends" == "base-files (= 13.8+deb13u6+kernora1), kernora-archive (>= 1.0)" ]] \
  || fail "wrong binary dependency: $depends"
essential=$(dpkg-deb --field "$deb" Essential)
[[ "$essential" == "no" || -z "$essential" ]] \
  || fail "base package must not be Essential"

temporary_root=$(mktemp -d /tmp/kernora-base-test.XXXXXX)
trap 'find "$temporary_root" -depth -delete' EXIT
dpkg-deb --extract "$deb" "$temporary_root/root"
if find "$temporary_root/root" -type f \
  ! -path "$temporary_root/root/usr/share/doc/kernora-base/*" \
  ! -path "$temporary_root/root/usr/share/kernora/workarounds/20-kernora-rtl8852ce.conf" \
  -print -quit | grep -q .; then
  fail "base package contains an unexpected file"
fi
cmp "$package_root/data/NetworkManager/20-kernora-rtl8852ce.conf" \
  "$temporary_root/root/usr/share/kernora/workarounds/20-kernora-rtl8852ce.conf" \
  || fail "optional RTL8852CE example is missing or changed during packaging"
[[ ! -e "$temporary_root/root/usr/lib/NetworkManager/conf.d/20-kernora-rtl8852ce.conf" ]] \
  || fail "withdrawn RTL8852CE policy is still automatically enabled"

dpkg-deb --control "$deb" "$temporary_root/control"
[[ -x "$temporary_root/control/postinst" ]] || fail "root ownership migration is missing"
grep -Fq 'chown 0:0 /' "$temporary_root/control/postinst" \
  || fail "upgrade does not repair root ownership"

printf 'kernora-base binary test: OK\n'
