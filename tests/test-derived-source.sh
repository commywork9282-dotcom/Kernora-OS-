#!/usr/bin/env bash
set -Eeuo pipefail

project_root=$(CDPATH= cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)
name=${1:?usage: test-derived-source.sh NAME}
package_root="$project_root/packages/derived/$name"
source_dir="$project_root/_build/source-packages"

fail() {
  printf '%s source test: %s\n' "$name" "$*" >&2
  exit 1
}

version=$(dpkg-parsechangelog -l"$package_root/changelog" -S Version)
file_version=${version#*:}
[[ "$version" == *kernora* ]] || fail "the derived version does not name Kernora: $version"
awk -v name="$name" -v version="$version" '$1 == name && $3 == version { found = 1 } END { exit !found }' \
  "$project_root/manifests/derived-packages.txt" \
  || fail "manifests/derived-packages.txt does not record $version"
grep -Fxq "$name" "$project_root/manifests/source-packages.txt" \
  || fail "manifests/source-packages.txt does not fetch $name"

patches=()
while read -r patch; do
  [[ -n "$patch" && "$patch" != \#* ]] || continue
  [[ -s "$package_root/patches/$patch" ]] || fail "patch in series is missing: $patch"
  grep -q '^Description: ' "$package_root/patches/$patch" || fail "patch has no DEP-3 description: $patch"
  patches+=("$patch")
done < "$package_root/patches/series"
(( ${#patches[@]} > 0 )) || fail "no Kernora patches"

dsc="$source_dir/${name}_${file_version}.dsc"
if [[ -s "$dsc" ]]; then
  grep -Fxq "Version: $version" "$dsc" || fail "source package has the wrong version"
  debian_tarball="$source_dir/${name}_${file_version}.debian.tar.xz"
  grep -q "${name}_${file_version}.debian.tar.xz" "$dsc" || fail "source package lacks its Debian tarball"
  contents=$(tar -tJf "$debian_tarball")
  for patch in "${patches[@]}"; do
    grep -Fxq "debian/patches/$patch" <<<"$contents" || fail "the Kernora patch is not in the source package: $patch"
  done
fi

printf '%s source test: OK\n' "$name"
