#!/usr/bin/env bash
set -Eeuo pipefail

project_root=$(CDPATH= cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)
package_root="$project_root/packages/native/kernora-base"

fail() {
  printf 'kernora-base source test: %s\n' "$*" >&2
  exit 1
}

for dependency in dpkg-parsechangelog grep; do
  command -v "$dependency" >/dev/null 2>&1 \
    || fail "required command not found: $dependency"
done

version=$(dpkg-parsechangelog -l"$package_root/debian/changelog" -S Version)
distribution=$(dpkg-parsechangelog \
  -l"$package_root/debian/changelog" -S Distribution)
[[ "$version" == "1.6.3" ]] || fail "unexpected source version"
[[ "$distribution" == "UNRELEASED" ]] \
  || fail "development package must remain UNRELEASED"
[[ "$(<"$package_root/debian/source/format")" == "3.0 (native)" ]] \
  || fail "wrong source format"
[[ -x "$package_root/debian/rules" ]] || fail "debian/rules is not executable"

control="$package_root/debian/control"
grep -Fxq 'Package: kernora-base' "$control" || fail "binary stanza is missing"
grep -Fxq 'Architecture: all' "$control" || fail "package is not architecture-all"
grep -Fxq 'Section: admin' "$control" || fail "wrong archive section"
grep -Fxq 'Standards-Version: 4.7.4' "$control" \
  || fail "wrong Standards-Version"
grep -Fxq ' base-files (= 13.8+deb13u7+kernora2),' "$control" \
  || fail "base-files dependency is not pinned to the Kernora build"
grep -Eq '^ kernora-archive \(>= 1\.0\),?$' "$control" \
  || fail "the package archives are not part of the base system"
if grep -Eq '^(Essential|Protected|Pre-Depends|Priority):' "$control"; then
  fail "base package declares an inappropriate control field"
fi

for tool in git curl wget htop fastfetch unzip zip 7zip; do
  grep -Fxq " $tool," "$package_root/debian/control" || grep -Fxq " $tool" "$package_root/debian/control" || fail "kernora-base does not bring $tool"
done

fastfetch="$package_root/data/fastfetch"
[[ -s "$fastfetch/kernora.txt" && -s "$fastfetch/kernora-small.txt" ]] || fail "the fastfetch logos are missing"
! grep -Fq '$' "$fastfetch/kernora.txt" "$fastfetch/kernora-small.txt" || fail "a logo has a \$ that fastfetch reads as a colour code"
grep -Fq '"source": "/usr/share/kernora/fastfetch/kernora.txt"' "$fastfetch/config.jsonc" \
  && grep -Fq '"source": "/usr/share/kernora/fastfetch/kernora-small.txt"' "$fastfetch/kernora-small.jsonc" \
  || fail "fastfetch does not use the Kernora logo"
grep -Fq '"modules": [' "$fastfetch/config.jsonc" && grep -Fq '"modules": [' "$fastfetch/kernora-small.jsonc" \
  || fail "fastfetch 2.40 prints only the logo without a module list"
grep -Fxq 'data/fastfetch/config.jsonc etc/xdg/fastfetch' "$package_root/debian/kernora-base.install" \
  || fail "the fastfetch config is not installed"

printf 'kernora-base source test: OK\n'
