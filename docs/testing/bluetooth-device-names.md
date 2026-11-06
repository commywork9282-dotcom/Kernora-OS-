# Bluetooth device names and discovery

The community report showed address aliases such as `5A-D8-EE-B7-A7-E4` as device names in Settings. BluezQt exposes BlueZ `Alias` through `device.name` and the remote `Name` separately through `device.remoteName`. A nonempty alias is not evidence that a remote name has been received.

Settings now preserves meaningful aliases, falls back to remote names, and updates when names arrive. Named devices appear first in an alphabetical list with an address tie-breaker. Devices without names remain accessible through an explicit toggle and retain their addresses. Advertised product identifiers such as `NBEGN` and `ELK-BLEDOM0B` are kept as supplied; the UI cannot manufacture a name that a device never broadcasts.

The pairing page owns a separate D-Bus connection for its discovery session. It requests discovery when the adapter becomes ready, even if another client is already scanning, and releases its own session on exit. Pending starts, adapter changes, failure/retry, power changes, and rapid page reentry are covered by the integration tests.

## Validation

`tests/bluetooth/run.sh` runs the installed Settings pages, KDE BluezQt, and the installed C++ discovery controller against a controlled BlueZ service on a private D-Bus daemon. Test data includes late remote names while Alias remains an address, unnamed devices, custom aliases and renaming, duplicate names, selecting the correct pairing address, stable ordering, and discovery ownership and lifecycle changes. It also captures the rendered pairing page using synthetic devices.

Two regression tests were run with the original pairing page in the same VM. Both failed as expected: late adapter discovery never started, and a remote name update left `5A-D8-EE-B7-A7-E4` as the row title instead of `Community Buds`. The corrected page passes both scenarios.

The packages for stable (`kernora-apps 1.1.64.4`) and demo (`kernora-apps 1.1.78.1`) were built independently against their corresponding SDKs. Source checks, binary contents, registered QML types, and local archive checks verify that the packaged files match the source. The update changes only `kernora-apps`; existing desktop package versions are retained.

Final installed-package runs completed with **26 passed, 0 failed** in each channel. The two selected original-page regression cases failed as expected before the correction.

These are integration tests of actual Qt/BluezQt code in QEMU, not physical radio tests. Hardware-specific discovery, reception, firmware, pairing authentication, and devices that never provide a name still require testing with real devices.

## References

- [BlueZ Device API](https://bluez.readthedocs.io/en/latest/device-api/)
- [BlueZ Adapter API](https://bluez.readthedocs.io/en/latest/adapter-api/)
- [BluezQt Device API](https://api.kde.org/bluezqt-device.html)
