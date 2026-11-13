#!/usr/bin/env bash
set -Eeuo pipefail

project_root=$(CDPATH= cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)
package_root="$project_root/packages/native/kwin-effect-rounded-corners"
kwinrc="$project_root/packages/native/kernora-desktop/data/xdg-kwinrc/kwinrc"

fail() {
  printf 'kwin-effect-rounded-corners source test: %s\n' "$*" >&2
  exit 1
}

for dependency in dpkg-parsechangelog grep python3; do
  command -v "$dependency" >/dev/null 2>&1 \
    || fail "required command not found: $dependency"
done

[[ "$(dpkg-parsechangelog -l"$package_root/debian/changelog" -S Version)" == "0.11.0+kernora1" ]] \
  || fail "unexpected source version"
[[ "$(dpkg-parsechangelog -l"$package_root/debian/changelog" -S Distribution)" == "UNRELEASED" ]] \
  || fail "development package must remain UNRELEASED"
[[ "$(<"$package_root/debian/source/format")" == "3.0 (native)" ]] || fail "wrong source format"
[[ -x "$package_root/debian/rules" ]] || fail "debian/rules is not executable"

control="$package_root/debian/control"
grep -Fxq 'Package: kwin-effect-rounded-corners' "$control" || fail "binary stanza is missing"
grep -Fxq ' kwin-dev (>= 4:6.3.6),' "$control" || fail "KWin headers are not a build dependency"
grep -Fq 'dh $@ --buildsystem=cmake' "$package_root/debian/rules" || fail "not built with CMake"
grep -Fq 'GNU GENERAL PUBLIC LICENSE' "$package_root/LICENSE" || fail "upstream licence is missing"
grep -Fq 'Robert Metsäranta' "$package_root/debian/copyright" || fail "upstream authors are missing from debian/copyright"
python3 -I -c 'import json, sys; m = json.load(open(sys.argv[1])); assert m["KPlugin"]["EnabledByDefault"] is True' \
  "$package_root/src/metadata.json" || fail "the effect is not enabled by default"
grep -Fq 'add_library(kwin4_effect_shapecorners' "$package_root/src/CMakeLists.txt" \
  || grep -Fq 'kwin4_effect_shapecorners' "$package_root/src/CMakeLists.txt" \
  || fail "effect target is missing"

python3 -I - "$kwinrc" <<'PY' || fail "Kernora defaults for the effect are wrong"
import configparser, sys
config = configparser.ConfigParser(interpolation=None, strict=False)
config.optionxform = str
config.read(sys.argv[1])
corners = config["Round-Corners"]
expected = {
    "Size": "12", "InactiveCornerRadius": "12", "UseSquircleShape": "false",
    "UseNativeDecorationShadows": "false", "SecondOutlineThickness": "0",
    "InactiveSecondOutlineThickness": "0", "OuterOutlineThickness": "0",
    "InactiveOuterOutlineThickness": "0", "OutlineColor": "255,255,255",
}
for key, value in expected.items():
    if corners.get(key) != value:
        raise SystemExit(key)
PY

printf 'kwin-effect-rounded-corners source test: OK\n'
