# Realtek RTL8852CE intermittent disconnects

`kernora-base` 1.3 provides a conservative power-saving workaround for the
in-kernel `rtw89_8852ce` driver (PCI ID `10ec:c852`). This is a candidate
mitigation for a user report, not a confirmed diagnosis of that machine.
The ISO already includes `firmware-realtek` and a supported in-kernel driver.

The package installs
`/usr/lib/NetworkManager/conf.d/20-kernora-rtl8852ce.conf`. Its connection
default matches only `driver:rtw89_8852ce` and sets `wifi.powersave=2`
(disabled). It applies to existing and new profiles whose power-saving
setting is `0` (default). Explicit profile values `1`, `2` and `3` remain
unchanged. Other Wi-Fi adapters and Ethernet retain their existing policy.
Disabling power saving can increase battery use on the affected adapter.

Installation reloads NetworkManager's configuration, without restarting it
or interrupting an active download. Reconnect Wi-Fi or reboot to apply the
new default. No firmware files, kernel modules or saved connections are
replaced. The driver still uses its normal PCIe ASPM configuration.

## Validation on the affected machine

After installing the package and reconnecting, check the adapter and the
effective power policy:

```sh
nmcli -f GENERAL.DEVICE,GENERAL.DRIVER device show
iw dev
iw dev INTERFACE get power_save
```

Replace `INTERFACE` with the Wi-Fi interface from `iw dev`. With a default
profile, the last command should report `Power save: off`. Test an idle
connection, sustained traffic, and suspend/resume under the same conditions
that previously caused disconnects. A QEMU virtio network cannot validate
RTL8852CE radio, firmware, power transitions or battery consumption.

If the profile explicitly enables power saving, inspect it first:

```sh
nmcli -g 802-11-wireless.powersave connection show uuid UUID
```

Replace `UUID` with the connection UUID shown by `nmcli connection show`.
To opt into the system default, set that profile's value to `0` using
`nmcli connection modify uuid UUID 802-11-wireless.powersave 0`, then reconnect.
This is a deliberate user choice; package installation does not rewrite it.

If another disconnect occurs, capture the kernel messages before rebooting:

```sh
uname -r
dpkg-query -W firmware-realtek network-manager
sudo journalctl -k -b --since '-20 min' --no-hostname --case-sensitive=no --grep='rtw89|8852|firmware|lps|pcie|aer'
```

Review messages before sharing. Firmware acknowledgements, PCIe errors,
roaming, router authentication and suspend failures require different fixes;
the model name alone does not distinguish them. Do not distribute an
out-of-tree DKMS driver, delete firmware blobs or disable ASPM globally based
only on this report.

## Reverting the default

Create an empty administrator override with the same filename:

```sh
sudo install -m 0644 /dev/null /etc/NetworkManager/conf.d/20-kernora-rtl8852ce.conf
sudo nmcli general reload conf
```

Reconnect or reboot. NetworkManager then ignores the vendor policy. Remove
that empty override and reload/reconnect to restore the Kernora default.

## References

- [NetworkManager configuration: device matching, connection defaults and administrator overrides](https://networkmanager.pages.freedesktop.org/NetworkManager/NetworkManager/NetworkManager.conf.html)
- [NetworkManager Wi-Fi power-saving values](https://networkmanager.pages.freedesktop.org/NetworkManager/NetworkManager/settings-802-11-wireless.html)
- [In-kernel RTL8852CE driver name and PCI ID in Linux 6.12.107](https://github.com/gregkh/linux/blob/v6.12.107/drivers/net/wireless/realtek/rtw89/rtw8852ce.c)
- [rtw89 maintainer guidance on optional power-management workarounds](https://github.com/lwfinger/rtw89/blob/main/README.md)

## Package validation, 12 October 2026

`make verify`, native source checks and both binary package checks passed.
In a disposable Kernora QEMU guest running Linux `6.12.107+deb13-amd64` and
NetworkManager `1.52.1`, upgrading `kernora-base` from 1.2 to 1.3 succeeded.
NetworkManager parsed the installed vendor policy, an empty administrator
file masked it, and an explicit administrator policy overrode it. Saved
profiles with default and explicitly enabled power saving retained their
settings. The running NetworkManager PID and active Ethernet connection
were unchanged by installation.

`kernora-apps` 1.1.33 depends on `kernora-base >= 1.3`, so its What's New entry
arrives with the corresponding policy. The installed native Qt module
returned the new entry in both English and Russian. The ISO pins are updated
for subsequent builds; the published ISO itself is unchanged.

Logs are in `out/test-logs/wifi-rtl8852ce/`. These checks validate packaging,
configuration loading and update behavior. They do not demonstrate that the
reporter's disconnects are fixed; RTL8852CE hardware validation is pending.

## Delivery

Published `kernora-base` 1.3 and `kernora-apps` 1.1.33 through the existing
signed [APT channel](https://commywork9282-dotcom.github.io/kernora-updates),
archive commit `370093a7b894925f24e4681af02c3ae1e366b915`. GitHub Pages
reported a successful build. An actual guest APT refresh verified the
public signature and selected these versions at archive priority 900.
Public package bytes match the locally tested artifacts and the signed
index:

| Package | SHA256 |
| --- | --- |
| kernora-base 1.3 | `fa084678d308958aafb1128c39a8a2b400dd54045b5ef410b56cbc0039f3c605` |
| kernora-apps 1.1.33 | `5ab75a355ae323b85ee6178b06d1a6f41d0899a74eb9909084b3388126744764` |

The [existing v1-ember-5 release](https://github.com/commywork9282-dotcom/Kernora-OS-/releases/tag/v1-ember-5)
has updated notes, both `.deb` files and their SHA256 attachments. No release
or tag was created. The main implementation commit is `66cbd18`; the ISO and
previously published package attachments are unchanged. What's New uses
entry `2026-10-13-6` with display date 12 October 2026.
