#!/usr/bin/env bash
set -Eeuo pipefail

project_root=$(CDPATH= cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)
package_root="$project_root/packages/derived/calamares"
source_dir="$project_root/_build/source-packages"

fail() {
  printf 'calamares source test: %s\n' "$*" >&2
  exit 1
}

version=$(dpkg-parsechangelog -l"$package_root/changelog" -S Version)
[[ "$version" == *kernora* ]] || fail "the derived version does not name Kernora: $version"
grep -Fxq "calamares     3.3.14-1              $version" "$project_root/manifests/derived-packages.txt" \
  || fail "manifests/derived-packages.txt does not record $version"

while read -r patch; do
  [[ -n "$patch" && "$patch" != \#* ]] || continue
  [[ -s "$package_root/patches/$patch" ]] || fail "patch in series is missing: $patch"
  grep -q '^Description: ' "$package_root/patches/$patch" || fail "patch has no DEP-3 description: $patch"
done < "$package_root/patches/series"

dsc="$source_dir/calamares_${version}.dsc"
if [[ -s "$dsc" ]]; then
  grep -Fxq "Version: $version" "$dsc" || fail "source package has the wrong version"
  grep -q "calamares_${version}.debian.tar.xz" "$dsc" || fail "source package lacks its Debian tarball"
  tar -tJf "$source_dir/calamares_${version}.debian.tar.xz" \
    | grep -Fxq 'debian/patches/kernora-material-partitions.patch' \
    || fail "the Kernora patch is not in the source package"
fi

printf 'calamares source test: OK\n'
