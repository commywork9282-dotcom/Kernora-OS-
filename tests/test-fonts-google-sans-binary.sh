#!/usr/bin/env bash
set -Eeuo pipefail

project_root=$(CDPATH= cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)
package_root="$project_root/packages/native/fonts-google-sans"
package_version=$(dpkg-parsechangelog -l"$package_root/debian/changelog" -S Version)
deb="$project_root/_build/binary-packages/fonts-google-sans_${package_version}_all.deb"

fail() {
  printf 'fonts-google-sans binary test: %s\n' "$*" >&2
  exit 1
}

[[ -s "$deb" ]] || fail "binary package does not exist"
[[ "$(dpkg-deb --field "$deb" Package)" == "fonts-google-sans" ]] || fail "wrong package name"
[[ "$(dpkg-deb --field "$deb" Version)" == "$package_version" ]] || fail "wrong package version"
[[ "$(dpkg-deb --field "$deb" Architecture)" == "all" ]] || fail "wrong package architecture"

temporary_root=$(mktemp -d /tmp/fonts-google-sans-test.XXXXXX)
trap 'find "$temporary_root" -depth -delete' EXIT
dpkg-deb --extract "$deb" "$temporary_root/root"
root="$temporary_root/root"

for font in GoogleSansFlex GoogleSans; do
  cmp -s "$package_root/fonts/$font.ttf" "$root/usr/share/fonts/truetype/google-sans/$font.ttf" \
    || fail "$font.ttf is missing or differs"
done
cmp -s "$package_root/fontconfig/56-google-sans-flex.conf" "$root/usr/share/fontconfig/conf.avail/56-google-sans-flex.conf" \
  || fail "the fontconfig rule is missing"
[[ "$(readlink "$root/etc/fonts/conf.d/56-google-sans-flex.conf")" == "/usr/share/fontconfig/conf.avail/56-google-sans-flex.conf" ]] \
  || fail "the fontconfig rule is not enabled"
[[ -s "$root/usr/share/doc/fonts-google-sans/copyright" ]] || fail "copyright is missing"
if find "$root/usr/share/fonts" -type f ! -perm 0644 | grep -q .; then
  fail "font files are not 0644"
fi

printf 'fonts-google-sans binary test: OK\n'
