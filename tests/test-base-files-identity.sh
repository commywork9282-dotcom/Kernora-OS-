#!/usr/bin/env bash
set -Eeuo pipefail

project_root=$(CDPATH= cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)
package_root="$project_root/packages/derived/base-files"

fail() {
  printf 'base-files identity test: %s\n' "$*" >&2
  exit 1
}

assert_file_line() {
  local file=$1
  local expected=$2
  grep -Fxq "$expected" "$file" || fail "$file does not contain: $expected"
}

# shellcheck disable=SC1091
source "$project_root/configs/project.env"
[[ "$DIST_NAME" == "Kernora OS" ]] || fail "unexpected DIST_NAME"
[[ "$DIST_ID" == "kernora" ]] || fail "unexpected DIST_ID"
[[ "$DIST_CODENAME" == "ember" ]] || fail "unexpected DIST_CODENAME"
[[ "$DIST_VERSION" == "1" ]] || fail "unexpected DIST_VERSION"

os_release="$package_root/etc/os-release"
assert_file_line "$os_release" 'PRETTY_NAME="Kernora OS 1"'
assert_file_line "$os_release" 'VERSION="1"'
assert_file_line "$os_release" 'NAME="Kernora OS"'
assert_file_line "$os_release" 'VERSION_ID="1"'
assert_file_line "$os_release" 'VERSION_CODENAME=ember'
assert_file_line "$os_release" 'ID=kernora'
assert_file_line "$os_release" 'ID_LIKE=debian'
assert_file_line "$os_release" 'LOGO=kernora-logo'
assert_file_line "$os_release" 'RELEASE_TYPE=development'

if grep -Eq '^(HOME|DOCUMENTATION|SUPPORT|BUG_REPORT|PRIVACY_POLICY|VENDOR)_URL=' "$os_release"; then
  fail "os-release contains a URL that has not been provisioned"
fi

assert_file_line "$package_root/origins/kernora" 'Vendor: Kernora'
assert_file_line "$package_root/origins/kernora" 'Parent: Debian'
assert_file_line "$package_root/debian/rules" 'VENDORFILE = kernora'
assert_file_line "$package_root/etc/debian_version" '13.7'

package_version=$(dpkg-parsechangelog -l"$package_root/debian/changelog" -S Version)
[[ "$package_version" == "13.8+deb13u7+kernora2" ]] || fail "unexpected package version"
dpkg --compare-versions "$package_version" gt '13.8+deb13u7' \
  || fail "Kernora version does not sort after its Debian base"

distribution=$(dpkg-parsechangelog -l"$package_root/debian/changelog" -S Distribution)
[[ "$distribution" == "UNRELEASED" ]] || fail "development package must remain UNRELEASED"

assert_file_line "$package_root/debian/control" \
  'Maintainer: Kernora Developers <developers@kernora.invalid>'
assert_file_line "$package_root/debian/control" \
  'XSBC-Original-Maintainer: Santiago Vila <sanvila@debian.org>'

printf 'base-files identity test: OK\n'

