#!/usr/bin/env bash
set -Eeuo pipefail

project_root=$(CDPATH= cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)
package_root="$project_root/packages/native/kernora-wallpapers"
package_version=$(dpkg-parsechangelog -l"$package_root/debian/changelog" -S Version)
deb="$project_root/_build/binary-packages/kernora-wallpapers_${package_version}_all.deb"

fail() {
  printf 'kernora-wallpapers binary test: %s\n' "$*" >&2
  exit 1
}

[[ -s "$deb" ]] || fail "binary package does not exist"
[[ "$(dpkg-deb --field "$deb" Package)" == "kernora-wallpapers" ]] || fail "wrong package name"
[[ "$(dpkg-deb --field "$deb" Version)" == "$package_version" ]] || fail "wrong package version"
[[ "$(dpkg-deb --field "$deb" Architecture)" == "all" ]] || fail "wrong package architecture"

temporary_root=$(mktemp -d /tmp/kernora-wallpapers-test.XXXXXX)
trap 'find "$temporary_root" -depth -delete' EXIT
dpkg-deb --extract "$deb" "$temporary_root/root"
installed="$temporary_root/root/usr/share/wallpapers"

count=0
for folder in "$package_root"/wallpapers/*/*/; do
  category=$(basename "$(dirname "$folder")")
  name=$(basename "$folder")
  target="$installed/kernora-$category-$name"
  cmp "$folder/metadata.json" "$target/metadata.json" || fail "kernora-$category-$name metadata differs"
  cmp "$folder/contents/images/3840x2160.jpg" "$target/contents/images/3840x2160.jpg" \
    || fail "kernora-$category-$name image differs"
  if [[ -e "$folder/contents/images_dark/3840x2160.jpg" ]]; then
    cmp "$folder/contents/images_dark/3840x2160.jpg" "$target/contents/images_dark/3840x2160.jpg" \
      || fail "kernora-$category-$name dark image differs"
  fi
  count=$((count + 1))
done
(( count >= 20 )) || fail "too few wallpapers installed"
[[ -s "$temporary_root/root/usr/share/doc/kernora-wallpapers/copyright" ]] || fail "copyright is missing"
if find "$installed" -type f ! -perm 0644 | grep -q .; then
  fail "wallpaper files are not 0644"
fi

printf 'kernora-wallpapers binary test: OK\n'
