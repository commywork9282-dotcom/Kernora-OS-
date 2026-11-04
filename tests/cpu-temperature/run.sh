#!/usr/bin/env bash
set -Eeuo pipefail
project_root=$(CDPATH= cd -- "$(dirname -- "${BASH_SOURCE[0]}")/../.." && pwd)
temporary=$(mktemp -d /tmp/kernora-cpu-test.XXXXXX)
trap 'rm -rf "$temporary"' EXIT
mkdir "$temporary/widget"
cp "$project_root/packages/native/kernora-desktop/data/widgets/common/TemperatureCard.qml" "$temporary/widget/"
cp "$project_root/tests/cpu-temperature/"*.qml "$temporary/"
if [[ ${1:-} == --preview ]]; then
  /usr/lib/qt6/bin/qml "$temporary/Preview.qml"
else
  /usr/lib/qt6/bin/qmltestrunner -input "$temporary" "$@"
fi
