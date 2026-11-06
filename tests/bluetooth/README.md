# Bluetooth integration tests

Run on an installed Kernora system with the matching `kernora-apps` package:

```sh
sudo apt-get install cmake g++ qt6-declarative-dev libkf6i18n-dev qml6-module-qttest python3-dbus python3-gi
./tests/bluetooth/run.sh
```

The runner needs a graphical session. It loads the installed Settings pages, the installed `BluetoothDiscovery` plugin, and KDE BluezQt. A private D-Bus daemon and a controlled BlueZ service provide adapters and devices; no physical Bluetooth adapter is used. The translation context matches the application host.

Coverage includes delayed remote names with a stale address alias, custom aliases, unnamed devices, stable ordering, duplicate device names, pairing the selected address, adapters appearing after the page opens, overlapping discovery clients, power cycling, retrying failed searches, adapter changes, and closing or reopening the page while discovery is pending.

Individual tests can be selected with QtTest arguments, for example:

```sh
./tests/bluetooth/run.sh BluetoothDevices::test_remote_name_arrives
```

The fake service verifies client ownership and cleanup. Radio firmware, reception, real device advertisements, pairing agents, and devices that never supply a name require hardware testing.
