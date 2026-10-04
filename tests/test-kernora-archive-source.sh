#!/usr/bin/env bash
set -Eeuo pipefail

project_root=$(CDPATH= cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)
package_root="$project_root/packages/native/kernora-archive"

fail() {
  printf 'kernora-archive source test: %s\n' "$*" >&2
  exit 1
}

for dependency in dpkg-parsechangelog gpg grep; do
  command -v "$dependency" >/dev/null 2>&1 \
    || fail "required command not found: $dependency"
done
# shellcheck disable=SC1091
source "$project_root/configs/project.env"

[[ "$(dpkg-parsechangelog -l"$package_root/debian/changelog" -S Version)" == "1.0" ]] \
  || fail "unexpected source version"
[[ "$(dpkg-parsechangelog -l"$package_root/debian/changelog" -S Distribution)" == "UNRELEASED" ]] \
  || fail "development package must remain UNRELEASED"
[[ "$(<"$package_root/debian/source/format")" == "3.0 (native)" ]] || fail "wrong source format"
[[ -x "$package_root/debian/rules" ]] || fail "debian/rules is not executable"

control="$package_root/debian/control"
grep -Fxq 'Package: kernora-archive' "$control" || fail "binary stanza is missing"
grep -Fxq 'Architecture: all' "$control" || fail "package is not architecture-all"
for dependency in debian-archive-keyring unattended-upgrades; do
  grep -Fxq " $dependency" "$control" || grep -Fxq " $dependency," "$control" \
    || fail "missing dependency: $dependency"
done

[[ "$DIST_ARCHIVE_KEY_FINGERPRINT" =~ ^[0-9A-F]{40}$ ]] || fail "the archive key fingerprint is not set"
keyring="$package_root/keyrings/kernora-archive-keyring.asc"
gnupg_home=$(mktemp -d)
trap 'rm -rf -- "$gnupg_home"' EXIT
fingerprint=$(GNUPGHOME=$gnupg_home gpg --batch --quiet --show-keys --with-colons "$keyring" \
  | awk -F: '$1 == "fpr" && !seen { print $10; seen = 1 }')
[[ "$fingerprint" == "$DIST_ARCHIVE_KEY_FINGERPRINT" ]] || fail "the keyring is not the archive key"
grep -Fq 'BEGIN PGP PRIVATE KEY' "$keyring" && fail "the keyring holds a private key"

apt="$package_root/apt"
grep -Fxq 'URIs: https://deb.debian.org/debian' "$apt/debian.sources" || fail "no Debian archive"
grep -Fxq 'Suites: trixie-security' "$apt/debian.sources" || fail "no Debian security updates"
if grep -rq 'snapshot.debian.org' "$apt"; then
  fail "the installed system must not use the build snapshot"
fi
grep -Fxq 'Signed-By: /usr/share/keyrings/kernora-archive-keyring.asc' "$apt/kernora.sources" \
  || fail "the Kernora archive is not signed by its key"
kernora_uri=$(awk '/^URIs:/ { print $2 }' "$apt/kernora.sources")
[[ "$kernora_uri" == "$DIST_UPDATES_URL" ]] || fail "kernora.sources does not point at $DIST_UPDATES_URL"
kernora_host=${kernora_uri#https://}
kernora_host=${kernora_host%%/*}
grep -Fxq "Pin: origin $kernora_host" "$apt/kernora-archive.pref" \
  || fail "Kernora packages are not preferred over Debian's"
grep -Fq '"origin=Debian,codename=trixie-security,label=Debian-Security";' "$apt/51kernora-unattended-upgrades" \
  || fail "security updates are not installed automatically"
grep -Fxq 'APT::Periodic::Unattended-Upgrade "1";' "$apt/21kernora-auto-upgrades" \
  || fail "unattended upgrades are not enabled"
for timer in apt-daily apt-daily-upgrade; do
  grep -Fxq 'ConditionKernelCommandLine=!boot=live' "$package_root/systemd/$timer.timer.d/kernora-live.conf" \
    || fail "$timer runs in the live session"
done

printf 'kernora-archive source test: OK\n'
