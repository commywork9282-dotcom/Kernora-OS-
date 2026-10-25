#!/usr/bin/env bash
set -Eeuo pipefail

project_root=$(CDPATH= cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)

fail() {
  printf 'publish-updates test: %s\n' "$*" >&2
  exit 1
}

for dependency in apt-cache apt-get dpkg-deb dpkg-scanpackages dpkg-scansources dpkg-source \
  git gpg gpgconf gzip tar; do
  command -v "$dependency" >/dev/null 2>&1 || fail "required command not found: $dependency"
done

codename=$(source "$project_root/configs/project.env" && printf '%s' "$DIST_CODENAME")
arch=$(source "$project_root/configs/upstream/base.env" && printf '%s' "$BASE_ARCH")
stable=$codename
demo=$codename-demo

temporary_root=$(mktemp -d /tmp/kernora-publish-test.XXXXXX)
project="$temporary_root/project"
remote="$temporary_root/remote.git"
gnupg_home="$project/_state/gnupg/archive"
keyring="$project/packages/native/kernora-archive/keyrings/kernora-archive-keyring.asc"
cleanup() {
  gpgconf --homedir "$gnupg_home" --kill gpg-agent >/dev/null 2>&1 || true
  rm -rf -- "$temporary_root"
}
trap cleanup EXIT

mkdir -p "$project/scripts/lib" "$project/configs/upstream" "$project/_build" "${keyring%/*}" "$gnupg_home"
chmod 0700 "$gnupg_home"
install -m 0755 "$project_root/scripts/publish-updates" "$project/scripts/"
install -m 0644 "$project_root/scripts/lib/common.sh" "$project/scripts/lib/"
install -m 0644 "$project_root/configs/upstream/base.env" "$project/configs/upstream/"
git init --quiet --bare --initial-branch=main "$remote"
git init --quiet "$project"
git -C "$project" config user.name "Kernora Test"
git -C "$project" config user.email test@kernora.invalid

gpg --homedir "$gnupg_home" --batch --quiet --pinentry-mode loopback --passphrase '' \
  --quick-generate-key 'Kernora Test <test@kernora.invalid>' ed25519 sign never 2>/dev/null
fingerprint=$(gpg --homedir "$gnupg_home" --batch --with-colons --list-secret-keys 2>/dev/null \
  | awk -F: '$1 == "fpr" { print $10; exit }')
gpg --homedir "$gnupg_home" --batch --armor --export "$fingerprint" > "$keyring"
sed -e "s|^DIST_UPDATES_REPOSITORY=.*|DIST_UPDATES_REPOSITORY=$remote|" \
  -e "s|^DIST_ARCHIVE_KEY_FINGERPRINT=.*|DIST_ARCHIVE_KEY_FINGERPRINT=$fingerprint|" \
  "$project_root/configs/project.env" > "$project/configs/project.env"

build_archive() {
  local archive="$project/out/archive" spec name version tag pool work root
  rm -rf -- "$archive" "$temporary_root/work"
  mkdir -p "$archive/dists/$stable/main/binary-$arch" "$archive/dists/$stable/main/source"
  for spec in "$@"; do
    read -r name version tag <<< "$spec"
    pool="$archive/pool/main/${name:0:1}/$name"
    work="$temporary_root/work/$name-$version"
    root="$temporary_root/work/root-$name"
    mkdir -p "$pool" "$work/debian/source" "$root/DEBIAN" "$root/usr/share/$name"
    printf '%s\n' "$tag" > "$work/tag"
    printf '%s\n' "$tag" > "$root/usr/share/$name/tag"
    printf '3.0 (native)\n' > "$work/debian/source/format"
    printf 'Source: %s\nMaintainer: Kernora Test <test@kernora.invalid>\n\nPackage: %s\nArchitecture: all\nDescription: test package\n test package\n' \
      "$name" "$name" > "$work/debian/control"
    printf '%s (%s) UNRELEASED; urgency=medium\n\n  * Test.\n\n -- Kernora Test <test@kernora.invalid>  Sun, 25 Oct 2026 12:00:00 +0000\n' \
      "$name" "$version" > "$work/debian/changelog"
    printf '#!/usr/bin/make -f\n%%:\n\tdh $@\n' > "$work/debian/rules"
    chmod 0755 "$work/debian/rules"
    (cd "$work" && SOURCE_DATE_EPOCH=1761393600 dpkg-source --build . >/dev/null 2>&1)
    mv "$temporary_root/work/${name}_${version}.dsc" "$temporary_root/work/${name}_${version}.tar.xz" "$pool/"
    printf 'Package: %s\nVersion: %s\nArchitecture: all\nMaintainer: Kernora Test <test@kernora.invalid>\nDescription: test package\n test package\n' \
      "$name" "$version" > "$root/DEBIAN/control"
    SOURCE_DATE_EPOCH=1761393600 dpkg-deb --root-owner-group --build "$root" \
      "$pool/${name}_${version}_all.deb" >/dev/null
  done
  (
    cd "$archive"
    dpkg-scanpackages --arch "$arch" pool/main /dev/null > "dists/$stable/main/binary-$arch/Packages"
    dpkg-scansources pool/main /dev/null > "dists/$stable/main/source/Sources"
  ) 2>/dev/null
  gzip -n -9 -c "$archive/dists/$stable/main/binary-$arch/Packages" > "$archive/dists/$stable/main/binary-$arch/Packages.gz"
  gzip -n -9 -c "$archive/dists/$stable/main/source/Sources" > "$archive/dists/$stable/main/source/Sources.gz"
  printf 'unsigned\n' > "$archive/dists/$stable/InRelease"
}

publish() {
  "$project/scripts/publish-updates" "$@" > "$temporary_root/out" 2> "$temporary_root/err"
}

refused() {
  local message=$1
  shift
  if publish "$@"; then
    fail "publishing $* went through, expected: $message"
  fi
  grep -Fq "$message" "$temporary_root/err" || fail "unexpected error: $(<"$temporary_root/err")"
}

site="$temporary_root/site"
fetch_site() {
  rm -rf -- "$site"
  mkdir -p "$site"
  git -C "$remote" archive main | tar -x -C "$site"
}

apt_root="$temporary_root/apt"
candidate() {
  local package=$1 suite
  shift
  rm -rf -- "$apt_root"
  mkdir -p "$apt_root/etc/sources.list.d" "$apt_root/etc/preferences.d" "$apt_root/etc/apt.conf.d" \
    "$apt_root/lists/partial" "$apt_root/cache/archives/partial" "$apt_root/state"
  : > "$apt_root/state/status"
  for suite in "$@"; do
    printf 'Types: deb\nURIs: file:%s\nSuites: %s\nComponents: main\nSigned-By: %s\n' \
      "$site" "$suite" "$site/kernora-archive-keyring.asc" > "$apt_root/etc/sources.list.d/$suite.sources"
  done
  printf 'Package: *\nPin: origin ""\nPin-Priority: 900\n' > "$apt_root/etc/preferences.d/kernora.pref"
  cat > "$apt_root/apt.conf" <<CONF
Dir::Etc "$apt_root/etc/";
Dir::Etc::sourcelist "sources.list";
Dir::Etc::sourceparts "sources.list.d";
Dir::Etc::preferences "preferences";
Dir::Etc::preferencesparts "preferences.d";
Dir::Etc::parts "apt.conf.d";
Dir::Etc::trusted "trusted.gpg";
Dir::Etc::trustedparts "trusted.gpg.d";
Dir::State "$apt_root/state/";
Dir::State::lists "$apt_root/lists/";
Dir::State::status "$apt_root/state/status";
Dir::Cache "$apt_root/cache/";
Debug::NoLocking "true";
APT::Architecture "$arch";
APT::Architectures { "$arch"; };
CONF
  LC_ALL=C APT_CONFIG="$apt_root/apt.conf" apt-get -q update > "$temporary_root/apt.log" 2>&1 \
    || fail "apt-get update failed: $(<"$temporary_root/apt.log")"
  if grep -Eq '^(W|E): ' "$temporary_root/apt.log"; then
    fail "apt-get update complained: $(grep -E '^(W|E): ' "$temporary_root/apt.log")"
  fi
  LC_ALL=C APT_CONFIG="$apt_root/apt.conf" apt-cache policy "$package" | awk '$1 == "Candidate:" { print $2 }'
}

suite_field() {
  awk -v field="$2:" '$1 == field { print $2; exit }' "$site/dists/$1/Release"
}

build_archive "alpha 1.0 a" "beta 2.0 b"
refused "nothing is published yet" --demo
publish || fail "the first publication failed: $(<"$temporary_root/err")"
fetch_site
[[ "$(suite_field "$stable" Suite)" == "$stable" ]] || fail "the stable suite is named wrong"
[[ "$(suite_field "$demo" Suite)" == "$demo" ]] || fail "the demo suite is named wrong"
[[ "$(suite_field "$stable" Codename)" == "$stable" ]] || fail "the stable codename is wrong"
[[ "$(suite_field "$demo" Codename)" == "$demo" ]] || fail "the demo codename is wrong"
[[ ! -s "$site/dists/$demo/main/binary-$arch/Packages" ]] || fail "the demo suite is not empty at first"
[[ "$(candidate alpha "$stable" "$demo")" == "1.0" ]] || fail "alpha 1.0 is not the candidate"
[[ "$(candidate beta "$stable")" == "2.0" ]] || fail "beta 2.0 is not the candidate"
grep -Fxq 'demo: empty' "$temporary_root/out" || fail "the empty demo is not reported"

refused "nothing in out/archive is newer" --demo

build_archive "alpha 1.1 a2" "beta 2.0 b"
cp "$site/dists/$stable/InRelease" "$temporary_root/stable-inrelease"
publish --demo || fail "the demo publication failed: $(<"$temporary_root/err")"
grep -Fxq 'demo: alpha 1.1' "$temporary_root/out" || fail "alpha 1.1 is not reported in the demo"
fetch_site
cmp -s "$temporary_root/stable-inrelease" "$site/dists/$stable/InRelease" \
  || fail "a demo publication changed the normal updates"
[[ -s "$site/pool-demo/main/a/alpha/alpha_1.1_all.deb" ]] || fail "alpha 1.1 is not in the demo pool"
[[ -s "$site/pool/main/a/alpha/alpha_1.0_all.deb" ]] || fail "alpha 1.0 left the normal pool"
grep -q '^Package: beta$' "$site/dists/$demo/main/binary-$arch/Packages" && fail "unchanged beta went to the demo"
[[ "$(candidate alpha "$stable")" == "1.0" ]] || fail "systems without the demo see alpha 1.1"
[[ "$(candidate alpha "$stable" "$demo")" == "1.1" ]] || fail "systems with the demo do not get alpha 1.1"
[[ "$(candidate beta "$stable" "$demo")" == "2.0" ]] || fail "systems with the demo lost beta"

build_archive "alpha 1.1 a3" "beta 2.0 b"
refused "alpha 1.1 is already in the demo updates with other contents" --demo
refused "alpha 1.1 is in the demo updates with other contents"

build_archive "alpha 1.1 a2" "beta 2.1 b2" "gamma 1.0 c"
publish --demo || fail "the second demo publication failed: $(<"$temporary_root/err")"
fetch_site
[[ "$(candidate gamma "$stable" "$demo")" == "1.0" ]] || fail "a new package does not reach the demo"
[[ -z "$(candidate gamma "$stable")" || "$(candidate gamma "$stable")" == "(none)" ]] \
  || fail "a demo-only package reached the normal updates"

build_archive "alpha 1.1 a2" "beta 2.0 b"
publish || fail "releasing the demo failed: $(<"$temporary_root/err")"
fetch_site
[[ "$(candidate alpha "$stable")" == "1.1" ]] || fail "alpha 1.1 did not reach the normal updates"
[[ "$(candidate beta "$stable" "$demo")" == "2.1" ]] || fail "the newer beta left the demo"
[[ "$(candidate gamma "$stable" "$demo")" == "1.0" ]] || fail "gamma left the demo"
grep -q '^Package: alpha$' "$site/dists/$demo/main/binary-$arch/Packages" \
  && fail "released alpha stayed in the demo"
[[ ! -e "$site/pool-demo/main/a/alpha" ]] || fail "released alpha stayed in the demo pool"

build_archive "alpha 1.1 a2" "beta 2.1 b2" "gamma 1.0 c"
publish || fail "releasing everything failed: $(<"$temporary_root/err")"
fetch_site
[[ ! -s "$site/dists/$demo/main/binary-$arch/Packages" ]] || fail "the demo is not empty after a full release"
[[ "$(candidate beta "$stable" "$demo")" == "2.1" ]] || fail "beta 2.1 is missing after the release"

build_archive "alpha 1.1 a4" "beta 2.1 b2" "gamma 1.0 c"
publish || fail "publishing an unchanged version failed: $(<"$temporary_root/err")"
grep -Fq 'warning: alpha 1.1 changed but kept its version' "$temporary_root/err" \
  || fail "a change without a new version is not reported"

[[ "$(git -C "$remote" rev-list --count main)" == "1" ]] || fail "the published history grows"

printf 'publish-updates test: OK\n'
