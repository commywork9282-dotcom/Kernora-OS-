#!/usr/bin/env bash
set -Eeuo pipefail

project_root=$(CDPATH= cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)
name=${1:?usage: test-derived-binary.sh NAME}
package_root="$project_root/packages/derived/$name"
source_dir="$project_root/_build/source-packages"
binary_dir="$project_root/_build/binary-packages"

fail() {
  printf '%s binary test: %s\n' "$name" "$*" >&2
  exit 1
}

version=$(dpkg-parsechangelog -l"$package_root/changelog" -S Version)
file_version=${version#*:}
dsc="$source_dir/${name}_${file_version}.dsc"
[[ -s "$dsc" ]] || fail "source package is missing: $dsc"

binaries=$(awk -F': ' '/^Binary:/ { print $2 }' "$dsc" | tr -d ' ' | tr ',' ' ')
[[ -n "$binaries" ]] || fail "the source package declares no binary packages"
for binary in $binaries; do
  debs=("$binary_dir/${binary}_${file_version}"_*.deb)
  [[ -s "${debs[0]}" ]] || fail "binary package was not built: $binary"
  [[ "$(dpkg-deb -f "${debs[0]}" Version)" == "$version" ]] || fail "$binary has the wrong version"
done

case "$name" in
  polkit-kde-agent-1)
    deb=$(printf '%s\n' "$binary_dir/polkit-kde-agent-1_${file_version}"_*.deb | head -n1)
    contents=$(dpkg-deb -c "$deb")
    grep -q '/libexec/polkit-kde-authentication-agent-1$' <<<"$contents" \
      || fail "the authentication agent is missing from the package"
    ;;
esac

printf '%s binary test: OK\n' "$name"
