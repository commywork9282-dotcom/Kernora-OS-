#!/usr/bin/env bash
set -Eeuo pipefail
root=$(CDPATH= cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
cmake -S "$root" -B /tmp/kernora-bluetooth-test-build
cmake --build /tmp/kernora-bluetooth-test-build -j2
exec dbus-run-session -- bash -c '
  export DBUS_SYSTEM_BUS_ADDRESS="$DBUS_SESSION_BUS_ADDRESS"
  python3 "$1/bluez_service.py" > /tmp/kernora-bluez-test.log 2>&1 &
  service=$!
  trap '\''kill "$service" 2>/dev/null || true'\'' EXIT
  for attempt in {1..50}; do
    if dbus-send --session --print-reply --dest=org.bluez / org.kernora.BluetoothTest.Counts >/dev/null 2>&1; then break; fi
    sleep 0.1
  done
  /tmp/kernora-bluetooth-test-build/bluetooth-tests -input "$1/tst_bluetooth.qml" "${@:2}"
' bash "$root" "$@"
