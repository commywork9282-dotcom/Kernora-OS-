#!/usr/bin/env bash
set -Eeuo pipefail
root=$(CDPATH= cd -- "$(dirname -- "${BASH_SOURCE[0]}")/../.." && pwd)
old_deb=$(realpath "${1:?Pass the previous kernora-archive 1.2 .deb}")
version=$(dpkg-parsechangelog -l"$root/packages/native/kernora-archive/debian/changelog" -S Version)
new_deb="$root/_build/binary-packages/kernora-archive_${version}_all.deb"
cache="$root/_cache/chroots/trixie-amd64-buildd.tar.xz"
[[ "$(dpkg-deb -f "$old_deb" Package)" == kernora-archive ]]
[[ "$(dpkg-deb -f "$old_deb" Version)" == 1.2 ]]
[[ -s "$new_deb" && -s "$cache" ]]
temporary=$(mktemp -d /tmp/kernora-apt-smoke.XXXXXX)
chmod 0777 "$temporary"
cleanup() {
    if [[ -d "$temporary/rootfs" ]]; then
        unshare --map-auto --setuid 0 --setgid 0 find "$temporary/rootfs" -depth -delete
    fi
    find "$temporary" -depth -delete
}
trap cleanup EXIT
curl --fail --silent --show-error --location --proto '=https' --tlsv1.2 \
    --output "$temporary/proton-release.deb" \
    https://repo.protonvpn.com/debian/dists/stable/main/binary-all/protonvpn-stable-release_1.0.10_all.deb
printf '%s  %s\n' c8a9fffb4ebdd63db08ce7f11c9b0ac394064ae6a210feb9ab63a0f7d8d060a7 "$temporary/proton-release.deb" | sha256sum --check

install -m 0644 "$cache" "$temporary/cache.tar.xz"
install -m 0644 "$old_deb" "$temporary/archive-old.deb"
install -m 0644 "$new_deb" "$temporary/archive-new.deb"
install -m 0644 "$root/tests/apt-availability/smoke.sh" "$temporary/smoke.sh"
unshare --map-auto --setuid 0 --setgid 0 --mount --pid --fork bash -c '

    set -Eeuo pipefail
    destination="$1/rootfs"
    mkdir -p "$destination"
    tar -xJf "$1/cache.tar.xz" -C "$destination"
    mkdir -p "$destination/build"
    cp "$1/archive-old.deb" "$destination/build/"
    cp "$1/archive-new.deb" "$destination/build/"
    cp "$1/proton-release.deb" "$destination/build/"
    cp "$1/smoke.sh" "$destination/build/"
    dpkg-deb --fsys-tarfile "$1/archive-old.deb" | tar -xOf - ./etc/apt/sources.list.d/debian.sources > "$destination/build/old-debian.sources"
    cp -L /etc/resolv.conf "$destination/etc/resolv.conf"
    mount -t proc proc "$destination/proc"
    chroot "$destination" /bin/bash /build/smoke.sh
' kernora-apt-smoke "$temporary"
