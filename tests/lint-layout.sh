#!/usr/bin/env bash
set -Eeuo pipefail

project_root=$(CDPATH= cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)

required_paths=(
  archive/reprepro/conf/distributions.in
  configs/project.env
  configs/live/packages.txt
  configs/live/excluded-packages.txt
  configs/live/grub.cfg
  configs/live/live-user.env
  configs/live/sddm-autologin.conf.in
  configs/rootfs/minimal-packages.txt
  configs/upstream/base.env
  configs/upstream/debian.sources.in
  docs/ARCHITECTURE.md
  keys/debian-trixie-fingerprints.txt
  manifests/source-packages.txt
  manifests/derived-packages.txt
  manifests/native-packages.txt
  packages/native
  packages/derived
  packages/derived/base-files/debian/changelog
  packages/derived/base-files/etc/os-release
  packages/native/kernora-base/debian/control
  packages/native/kernora-base/debian/changelog
  packages/native/kernora-archive/debian/control
  packages/native/kernora-archive/debian/changelog
  packages/native/kernora-archive/keyrings/kernora-archive-keyring.asc
  packages/native/kernora-desktop/debian/control
  packages/native/kernora-desktop/debian/changelog
  packages/native/kernora-apps/debian/control
  packages/native/kernora-apps/debian/changelog
  packages/native/kernora-apps/CMakeLists.txt
  packages/native/kernora-desktop/data/ui/qmldir
  configs/live/kernora-live-language
  packages/native/kernora-desktop/data/calamares/settings.conf
  packages/native/kernora-desktop/data/wallpaper/org.kernora.shapes/metadata.json
  packages/native/kernora-desktop/data/icons/kernora-logo.svg
  packages/native/kernora-desktop/data/symbols.lock
  packages/native/kernora-desktop/data/shell/m3/qmldir
  packages/native/kernora-desktop/data/shell/launcher/metadata.json
  packages/native/kernora-desktop/data/shell/shade/metadata.json
  packages/native/kernora-desktop/tools/kernora_design.py
  packages/native/kernora-desktop/tools/m3color.py
  docs/DESKTOP.md
  scripts/preview-desktop
  configs/live/apt-preferences
  configs/live/kscreenlockerrc
  configs/live/kwalletrc
  scripts/fetch-sources
  scripts/bootstrap-debian-signer-keyring
  scripts/bootstrap-build-tools
  scripts/bootstrap-iso-tools
  scripts/build-base-files-source
  scripts/create-build-rootfs
  scripts/build-base-files-binary
  scripts/build-kernora-base-source
  scripts/build-kernora-base-binary
  scripts/build-kernora-archive-source
  scripts/build-kernora-archive-binary
  scripts/create-archive-key
  scripts/publish-updates
  tests/test-publish-updates.sh
  scripts/build-kernora-desktop-source
  scripts/build-kernora-desktop-binary
  scripts/create-development-archive-key
  scripts/build-local-archive
  scripts/build-minimal-rootfs
  scripts/build-live-rootfs
  scripts/build-iso
  scripts/smoke-test-iso
  scripts/unpack-sources
  tests/test-base-files-identity.sh
  tests/test-base-files-binary.sh
  tests/test-kernora-base-source.sh
  tests/test-kernora-base-binary.sh
  tests/test-kernora-archive-source.sh
  tests/test-kernora-archive-binary.sh
  tests/test-kernora-desktop-source.sh
  tests/test-kernora-desktop-binary.sh
  tests/test-local-archive.sh
  tests/test-minimal-rootfs.sh
  tests/test-live-rootfs.sh
  tests/test-iso.sh
)

for required_path in "${required_paths[@]}"; do
  [[ -e "$project_root/$required_path" ]] || {
    printf 'missing required path: %s\n' "$required_path" >&2
    exit 1
  }
done

if find "$project_root/keys" -type f \( -name '*.key' -o -name '*.sec' \) -print -quit \
  | grep -q .; then
  printf 'private-looking key material found under keys/\n' >&2
  exit 1
fi

printf 'layout test: OK\n'
