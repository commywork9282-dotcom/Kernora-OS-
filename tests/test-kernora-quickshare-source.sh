#!/usr/bin/env bash
set -Eeuo pipefail

project_root=$(CDPATH= cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)
package_root="$project_root/packages/native/kernora-quickshare"

fail() {
  printf 'kernora-quickshare source test: %s\n' "$*" >&2
  exit 1
}

for dependency in dpkg-parsechangelog grep python3; do
  command -v "$dependency" >/dev/null 2>&1 \
    || fail "required command not found: $dependency"
done

version=$(dpkg-parsechangelog -l"$package_root/debian/changelog" -S Version)
[[ "$version" == "1.0.2" ]] || fail "unexpected source version"
[[ "$(dpkg-parsechangelog -l"$package_root/debian/changelog" -S Distribution)" == "UNRELEASED" ]] \
  || fail "development package must remain UNRELEASED"
[[ "$(<"$package_root/debian/source/format")" == "3.0 (native)" ]] || fail "wrong source format"
[[ -x "$package_root/debian/rules" ]] || fail "debian/rules is not executable"
grep -Fxq 'Package: kernora-quickshare' "$package_root/debian/control" || fail "binary stanza is missing"
grep -q -- '--offline --frozen' "$package_root/debian/rules" || fail "the build may reach the network"
grep -Fxq 'version = "1.0.2"' "$package_root/Cargo.toml" || fail "Cargo.toml and the changelog disagree"

lock="$package_root/Cargo.lock"
[[ -s "$lock" ]] || fail "Cargo.lock is missing"
grep -Fq 'git+https://github.com/nozwock/rquickshare.git?rev=c9ac93f5584a4265e8da679ad689df5be1e80c6b#c9ac93f5584a4265e8da679ad689df5be1e80c6b' "$lock" \
  || fail "rqs_lib is not pinned to the reviewed commit"
if grep -Fq 'github.com/Martichou/sys_metrics' "$lock"; then
  fail "the AGPL sys_metrics crate is back; the shim must replace it"
fi
grep -Fq 'sys_metrics = { path = "shim/sys_metrics" }' "$package_root/Cargo.toml" \
  || fail "sys_metrics is not patched to the shim"
python3 - "$lock" <<'PYTHON' || fail "a crates.io package in Cargo.lock has no checksum"
import re
import sys

text = open(sys.argv[1], encoding="utf-8").read()
for block in text.split("[[package]]")[1:]:
    if 'source = "registry+' in block and "checksum = " not in block:
        raise SystemExit(re.search(r'name = "([^"]+)"', block).group(1))
PYTHON
grep -Eq '^QUICKSHARE_VENDOR_SHA256=[0-9a-f]{64}$' "$project_root/configs/upstream/quickshare.env" \
  || fail "the vendored crates are not pinned"

patch="$package_root/patches/rqs_lib.patch"
[[ -s "$patch" ]] || fail "the rqs_lib patch is missing"
grep -q 'has_bluetooth_adapter' "$patch" \
  || fail "rqs_lib would wait 25 seconds for bluez on computers without Bluetooth"
grep -q 'pick_peer_ip' "$patch" || fail "discovery would pick a random address of the other device"
grep -q '^+const MODEL_ID_SHARING: \[u8; 3\] = \[0xfc, 0x12, 0x8e\];' "$patch" \
  || fail "every Fast Pair advert would count as someone sharing nearby"
grep -q '^+            transport: Some(Transport::Le),' "$package_root/patches/btleplug.patch" \
  || fail "Bluetooth discovery would run classic inquiry next to Wi-Fi"
grep -q '^+    pub fn set_nearby_listener' "$patch" && grep -q 'sync_nearby_listener' "$package_root/src/main.rs" \
  || fail "the nearby Bluetooth scan would run all the time"
grep -q 'SNOOZE: Duration = Duration::from_secs(900)' "$package_root/src/nearby.rs" \
  || fail "a dismissed nearby prompt would come back right away"
grep -q '^\s*cargo test ' "$package_root/debian/rules" || fail "the package build skips the unit tests"
if grep -q '^+.*set_powered(true)' "$patch"; then
  fail "sharing must not switch Bluetooth on behind the user's back"
fi
grep -q 'unsafe_names()' "$package_root/src/main.rs" \
  || fail "incoming file names are not checked before asking"
grep -q "name.contains('/')" "$package_root/src/state.rs" \
  || fail "file names with a slash would be accepted"

for path in data/org.kernora.quickshare.desktop data/org.kernora.quickshare-autostart.desktop \
  data/org.kernora.QuickShare.service; do
  [[ -s "$package_root/$path" ]] || fail "missing $path"
done
grep -qx 'Exec=/usr/bin/kernora-quickshare' "$package_root/data/org.kernora.QuickShare.service" \
  || fail "D-Bus activation does not start the daemon"

if grep -RInE '^\s*//[^/!]' "$package_root/src" "$package_root/shim" | grep -v 'SPDX-' ; then
  fail "explanatory comments are not used in Kernora sources"
fi

printf 'kernora-quickshare source test: OK\n'
