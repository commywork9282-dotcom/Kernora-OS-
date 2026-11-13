#!/usr/bin/env bash
set -Eeuo pipefail

project_root=$(CDPATH= cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)
package_root="$project_root/packages/native/fonts-google-sans"

fail() {
  printf 'fonts-google-sans source test: %s\n' "$*" >&2
  exit 1
}

for dependency in dpkg-parsechangelog grep sha256sum; do
  command -v "$dependency" >/dev/null 2>&1 \
    || fail "required command not found: $dependency"
done

[[ "$(dpkg-parsechangelog -l"$package_root/debian/changelog" -S Version)" == "1.0" ]] \
  || fail "unexpected source version"
[[ "$(dpkg-parsechangelog -l"$package_root/debian/changelog" -S Distribution)" == "UNRELEASED" ]] \
  || fail "development package must remain UNRELEASED"
[[ "$(<"$package_root/debian/source/format")" == "3.0 (native)" ]] || fail "wrong source format"
[[ -x "$package_root/debian/rules" ]] || fail "debian/rules is not executable"

control="$package_root/debian/control"
grep -Fxq 'Package: fonts-google-sans' "$control" || fail "binary stanza is missing"
grep -Fxq 'Architecture: all' "$control" || fail "package is not architecture-all"
grep -Fxq 'usr/share/fontconfig/conf.avail/56-google-sans-flex.conf etc/fonts/conf.d/56-google-sans-flex.conf' \
  "$package_root/debian/links" || fail "the fontconfig rule is not enabled"

sha256sum --quiet -c - <<SUMS || fail "the font files are not the Google Fonts releases"
a9ac770798857d5e8ac593ced42b22e40a7c08cec98319f92b0eccc2783a77ba  $package_root/fonts/GoogleSansFlex.ttf
d0a87d835a944b8b40d0e82a5651bb59ab97b936a2aeed5946eb57e7b2a3a90a  $package_root/fonts/GoogleSans.ttf
SUMS
grep -Fq '<family>Google Sans Flex</family>' "$package_root/fontconfig/56-google-sans-flex.conf" \
  && grep -Fq '<accept>' "$package_root/fontconfig/56-google-sans-flex.conf" \
  && grep -Fq '<family>Google Sans</family>' "$package_root/fontconfig/56-google-sans-flex.conf" \
  || fail "Google Sans Flex does not fall back to Google Sans"
grep -Fxq 'License: OFL-1.1' "$package_root/debian/copyright" || fail "the font license is missing"
grep -Fq 'trademarks of Google' "$package_root/debian/copyright" || fail "the trademark note is missing"

printf 'fonts-google-sans source test: OK\n'
