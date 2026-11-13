#!/usr/bin/env bash
set -Eeuo pipefail

project_root=$(CDPATH= cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)
package_root="$project_root/packages/native/kernora-wallpapers"

fail() {
  printf 'kernora-wallpapers source test: %s\n' "$*" >&2
  exit 1
}

for dependency in dpkg-parsechangelog grep python3; do
  command -v "$dependency" >/dev/null 2>&1 \
    || fail "required command not found: $dependency"
done

[[ "$(dpkg-parsechangelog -l"$package_root/debian/changelog" -S Version)" == "1.0" ]] \
  || fail "unexpected source version"
[[ "$(dpkg-parsechangelog -l"$package_root/debian/changelog" -S Distribution)" == "UNRELEASED" ]] \
  || fail "development package must remain UNRELEASED"
[[ "$(<"$package_root/debian/source/format")" == "3.0 (native)" ]] || fail "wrong source format"
[[ -x "$package_root/debian/rules" ]] || fail "debian/rules is not executable"

control="$package_root/debian/control"
grep -Fxq 'Package: kernora-wallpapers' "$control" || fail "binary stanza is missing"
grep -Fxq 'Architecture: all' "$control" || fail "package is not architecture-all"
grep -Fq 'usr/share/wallpapers/kernora-$$category-$$name' "$package_root/debian/rules" \
  || fail "debian/rules does not install into /usr/share/wallpapers"

python3 -I - "$package_root" <<'PY' || fail "wallpaper metadata or images are invalid"
import json, os, struct, sys

root = sys.argv[1]
walls = os.path.join(root, "wallpapers")
copyright_text = open(os.path.join(root, "debian", "copyright"), encoding="utf-8").read()
categories = {"minerals", "curated", "culture", "for-fun", "motif", "cityscapes", "life",
              "textures", "landscapes", "art", "earth", "solid-colors"}
licenses = {"CC0-1.0", "Unsplash License"}


def jpeg_size(path):
    data = open(path, "rb").read()
    if data[:2] != b"\xff\xd8":
        raise SystemExit(path + ": not a JPEG")
    i = 2
    while i < len(data):
        marker = data[i + 1]
        length = struct.unpack(">H", data[i + 2:i + 4])[0]
        if marker in (0xC0, 0xC1, 0xC2):
            height, width = struct.unpack(">HH", data[i + 5:i + 9])
            return width, height
        i += 2 + length
    raise SystemExit(path + ": no frame header")


count = 0
ids = set()
for category in sorted(os.listdir(walls)):
    if category not in categories:
        raise SystemExit("unknown category " + category)
    for name in sorted(os.listdir(os.path.join(walls, category))):
        folder = os.path.join(walls, category, name)
        meta = json.load(open(os.path.join(folder, "metadata.json"), encoding="utf-8"))
        plugin = meta["KPlugin"]
        expected = "kernora-%s-%s" % (category, name)
        if plugin["Id"] != expected or plugin["Id"] in ids:
            raise SystemExit(folder + ": bad or duplicate Id")
        ids.add(plugin["Id"])
        if not plugin.get("Name") or not plugin.get("Name[ru]"):
            raise SystemExit(folder + ": missing names")
        if not plugin.get("Authors") or not all(a.get("Name") for a in plugin["Authors"]):
            raise SystemExit(folder + ": missing authors")
        if plugin.get("License") not in licenses:
            raise SystemExit(folder + ": license not allowed")
        if meta.get("KPackageStructure") != "Wallpaper/Images":
            raise SystemExit(folder + ": not a Wallpaper/Images package")
        if meta.get("X-Kernora-Category") != category:
            raise SystemExit(folder + ": category mismatch")
        if jpeg_size(os.path.join(folder, "contents", "images", "3840x2160.jpg")) != (3840, 2160):
            raise SystemExit(folder + ": light image is not 3840x2160")
        dark = os.path.join(folder, "contents", "images_dark", "3840x2160.jpg")
        if os.path.exists(dark) and jpeg_size(dark) != (3840, 2160):
            raise SystemExit(folder + ": dark image is not 3840x2160")
        if "Files: wallpapers/%s/%s/*" % (category, name) not in copyright_text:
            raise SystemExit(folder + ": not listed in debian/copyright")
        count += 1
if count < 20:
    raise SystemExit("too few wallpapers")
PY

printf 'kernora-wallpapers source test: OK\n'
