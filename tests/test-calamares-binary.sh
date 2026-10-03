#!/usr/bin/env bash
set -Eeuo pipefail

project_root=$(CDPATH= cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)
# shellcheck disable=SC1091
source "$project_root/configs/upstream/base.env"
version=$(dpkg-parsechangelog -l"$project_root/packages/derived/calamares/changelog" -S Version)
deb="$project_root/_build/binary-packages/calamares_${version}_${BASE_ARCH}.deb"

fail() {
  printf 'calamares binary test: %s\n' "$*" >&2
  exit 1
}

[[ -s "$deb" ]] || fail "package is missing: $deb"
[[ "$(dpkg-deb --field "$deb" Package)" == calamares ]] || fail "wrong package name"
[[ "$(dpkg-deb --field "$deb" Version)" == "$version" ]] || fail "wrong package version"

temporary_root=$(mktemp -d)
trap 'rm -rf "$temporary_root"' EXIT
dpkg-deb -x "$deb" "$temporary_root"

ui=$(find "$temporary_root/usr/lib" -name 'libcalamaresui.so.*' -type f | head -1)
[[ -n "$ui" ]] || fail "libcalamaresui is missing"
python3 - "$ui" <<'PYTHON' || fail "libcalamaresui was built without the Kernora patch"
import sys
sys.exit(0 if "prettyRadioButton".encode("utf-16-le") in open(sys.argv[1], "rb").read() else 1)
PYTHON
partition=$(find "$temporary_root/usr/lib" -path '*calamares/modules/partition/*' -name '*.so' | head -1)
[[ -n "$partition" ]] || fail "the partition module is missing"
grep -aq '#94a6fd' "$partition" || fail "the partition module lacks the Kernora palette"

printf 'calamares binary test: OK\n'
