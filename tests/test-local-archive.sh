#!/usr/bin/env bash
set -Eeuo pipefail

project_root=$(CDPATH= cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)
# shellcheck disable=SC1091
source "$project_root/configs/project.env"
# shellcheck disable=SC1091
source "$project_root/configs/upstream/base.env"

archive="$project_root/out/archive"
suite_root="$archive/dists/$DIST_CODENAME"
release="$suite_root/Release"
public_key="$archive/kernora-development-archive-keyring.gpg"

fail() {
  printf 'local archive test: %s\n' "$*" >&2
  exit 1
}

for dependency in apt-cache apt-get awk chmod dpkg-parsechangelog find \
  gpgv grep mkdir sha256sum; do
  command -v "$dependency" >/dev/null 2>&1 \
    || fail "required command not found: $dependency"
done

for file in \
  "$release" "$release.gpg" "$suite_root/InRelease" "$public_key" \
  "$suite_root/main/binary-$BASE_ARCH/Packages" \
  "$suite_root/main/binary-$BASE_ARCH/Packages.gz" \
  "$suite_root/main/source/Sources" \
  "$suite_root/main/source/Sources.gz"; do
  [[ -s "$file" ]] || fail "missing or empty file: $file"
done

gpgv --keyring "$public_key" "$release.gpg" "$release" >/dev/null 2>&1 \
  || fail "detached Release signature is invalid"
gpgv --keyring "$public_key" "$suite_root/InRelease" >/dev/null 2>&1 \
  || fail "InRelease signature is invalid"

temporary_root=$(mktemp -d /tmp/kernora-archive-test.XXXXXX)
chmod 0755 "$temporary_root"
trap 'find "$temporary_root" -depth -delete' EXIT
checksum_list="$temporary_root/checksums"
awk '
  /^SHA256:$/ { in_sha256 = 1; next }
  in_sha256 && /^[^ ]/ { in_sha256 = 0 }
  in_sha256 { print $1 "  " $3 }
' "$release" > "$checksum_list"
(
  cd "$suite_root"
  sha256sum --check --status "$checksum_list"
) || fail "an archive index does not match Release"

package_version=$(dpkg-parsechangelog \
  -l"$project_root/packages/derived/base-files/debian/changelog" -S Version)
meta_version=$(dpkg-parsechangelog \
  -l"$project_root/packages/native/kernora-base/debian/changelog" -S Version)
packages="$suite_root/main/binary-$BASE_ARCH/Packages"
sources="$suite_root/main/source/Sources"
grep -Fxq 'Package: base-files' "$packages" || fail "base-files is not indexed"
grep -Fxq "Version: $package_version" "$packages" || fail "wrong binary version"
grep -Fxq 'Package: kernora-base' "$packages" || fail "kernora-base is not indexed"
grep -Fxq "Version: $meta_version" "$packages" || fail "wrong metapackage version"
grep -Fxq 'Package: base-files' "$sources" || fail "base-files source is not indexed"
grep -Fxq "Version: $package_version" "$sources" || fail "wrong source version"
grep -Fxq 'Package: kernora-base' "$sources" \
  || fail "kernora-base source is not indexed"
grep -Fxq 'Package: kernora-archive' "$packages" || fail "kernora-archive is not indexed"
grep -Fxq 'Package: kernora-archive' "$sources" \
  || fail "kernora-archive source is not indexed"
calamares_version=$(dpkg-parsechangelog \
  -l"$project_root/packages/derived/calamares/changelog" -S Version)
grep -Fxq "Version: $calamares_version" "$packages" \
  || fail "the Kernora calamares is not indexed"
grep -Fxq 'Package: calamares' "$sources" || fail "calamares source is not indexed"
polkit_version=$(dpkg-parsechangelog \
  -l"$project_root/packages/derived/polkit-kde-agent-1/changelog" -S Version)
grep -Fxq "Version: $polkit_version" "$packages" \
  || fail "the Kernora authentication agent is not indexed"
grep -Fxq 'Package: polkit-kde-agent-1' "$sources" \
  || fail "polkit-kde-agent-1 source is not indexed"
grep -Fxq 'Package: kernora-desktop' "$packages" \
  || fail "kernora-desktop is not indexed"
grep -Fxq 'Package: kernora-calamares' "$packages" \
  || fail "kernora-calamares is not indexed"
grep -Fxq 'Package: kernora-desktop' "$sources" \
  || fail "kernora-desktop source is not indexed"
grep -Fxq 'Package: kernora-quickshare' "$packages" \
  || fail "kernora-quickshare is not indexed"
grep -Fxq 'Package: kernora-quickshare' "$sources" \
  || fail "kernora-quickshare source is not indexed"
grep -Fxq "Origin: $DIST_NAME" "$release" || fail "wrong archive origin"
grep -Fxq "Codename: $DIST_CODENAME" "$release" || fail "wrong archive codename"

apt_root="$temporary_root/apt"
mkdir -p \
  "$apt_root/etc/sources.list.d" \
  "$apt_root/state/lists/partial" \
  "$apt_root/cache/archives/partial"
printf 'deb [signed-by=%s] file:%s %s main\n' \
  "$public_key" "$archive" "$DIST_CODENAME" \
  > "$apt_root/etc/sources.list"
apt_options=(
  -o "Dir::Etc::sourcelist=$apt_root/etc/sources.list"
  -o "Dir::Etc::sourceparts=$apt_root/etc/sources.list.d"
  -o "Dir::State=$apt_root/state"
  -o 'Dir::State::status=/dev/null'
  -o "Dir::Cache=$apt_root/cache"
  -o 'APT::Get::List-Cleanup=0'
  -o 'Acquire::Languages=none'
)
apt-get "${apt_options[@]}" update >/dev/null \
  || fail "APT rejected the signed archive"
apt-cache "${apt_options[@]}" show base-files > "$temporary_root/base-files.txt" \
  || fail "APT cannot read base-files from the archive"
grep -Fxq "Version: $package_version" "$temporary_root/base-files.txt" \
  || fail "APT selected the wrong base-files version"
apt-cache "${apt_options[@]}" show kernora-base \
  > "$temporary_root/kernora-base.txt" \
  || fail "APT cannot read kernora-base from the archive"
grep -Fxq "Version: $meta_version" "$temporary_root/kernora-base.txt" \
  || fail "APT selected the wrong kernora-base version"
grep -E '^Depends: ' "$temporary_root/kernora-base.txt" \
  | grep -Fq "Depends: base-files (= $package_version), kernora-archive (>= 1.0)" \
  || fail "APT sees the wrong Kernora identity dependency"

printf 'local archive test: OK\n'
