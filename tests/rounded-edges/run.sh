#!/usr/bin/env bash
set -Eeuo pipefail
project_root=$(CDPATH= cd -- "$(dirname -- "${BASH_SOURCE[0]}")/../.." && pwd)
if [[ ${KERNORA_EDGE_RAW_RENDERER:-0} != 1 ]]; then
    source "$project_root/packages/native/kernora-desktop/data/plasma-env/kernora-qtquick-style.sh"
fi
temporary=$(mktemp -d /tmp/kernora-edges-test.XXXXXX)
trap 'rm -rf "$temporary"' EXIT
mkdir "$temporary/ui" "$temporary/m3"
cp "$project_root/packages/native/kernora-desktop/data/ui/Avatar.qml" "$project_root/packages/native/kernora-desktop/data/ui/IconCircle.qml" "$temporary/ui/"
cp "$project_root/packages/native/kernora-desktop/data/ui/AppIcon.qml" "$temporary/ui/"
sed 's/import "m3"/import org.kernora.m3/' "$project_root/packages/native/kernora-desktop/data/shell/launcher/contents/ui/DrawerTile.qml" > "$temporary/ui/DrawerTile.qml"
sed '1i import org.kernora.m3' "$project_root/packages/native/kernora-desktop/data/shell/m3/MStateLayer.qml" > "$temporary/m3/MStateLayer.qml"
sed '1i import org.kernora.m3' "$project_root/packages/native/kernora-desktop/data/shell/m3/MIcon.qml" > "$temporary/m3/MIcon.qml"
cp "$project_root/tests/rounded-edges/"*.qml "$project_root/tests/rounded-edges/"*.svg "$temporary/"
result=0
/usr/lib/qt6/bin/qmltestrunner -input "$temporary" "$@" || result=$?
if [[ -n ${KERNORA_EDGE_CAPTURE_DIR:-} ]]; then
    mkdir -p "$KERNORA_EDGE_CAPTURE_DIR"
    cp "$temporary"/capture-*.png "$KERNORA_EDGE_CAPTURE_DIR/"
fi
exit "$result"
