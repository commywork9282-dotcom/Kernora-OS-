# Realtek RTL8852CE intermittent disconnects

## Current status: automatic workaround withdrawn in 1.4

After the 1.3 update, the reporter described packet loss and lag spikes in
CS2. This is a network-latency report, not a confirmed rendering freeze.
There is no hardware trace establishing that the Kernora power-saving change
caused it. Version 1.4 withdraws that unvalidated automatic default to allow
comparison with the previous Wi-Fi behavior, without adding further driver
parameters. The original disconnect report remains unresolved.

Upgrade to `kernora-base` 1.4 and `kernora-apps` 1.1.34, then **reboot**.
The old vendor policy in `/usr/lib/NetworkManager/conf.d` is removed by dpkg.
The package reloads configuration but does not restart the network, rewrite
saved profiles, remove administrator overrides or change Steam/CS2 launch
options. A reboot is needed for a clean comparison: removing a configuration
default does not necessarily reset an already running radio's power state.

The rollback is a diagnostic and recovery step, not a proven fix for packet
loss. Compare the same match conditions after reboot. If the loss persists,
compare Wi-Fi with Ethernet on the same machine, and capture the kernel
messages after a spike using the command below. Game-server or Internet
route loss, local radio loss and rendering stalls require different evidence.

The optional example is now installed at
`/usr/share/kernora/workarounds/20-kernora-rtl8852ce.conf`, outside every
NetworkManager configuration directory. It has no automatic effect. To opt
in deliberately when investigating low-power failures, copy it into
`/etc/NetworkManager/conf.d` without overwriting an existing administrator
configuration:

```sh
sudo cp --no-clobber /usr/share/kernora/workarounds/20-kernora-rtl8852ce.conf /etc/NetworkManager/conf.d/
sudo nmcli general reload conf
```

Reconnect or reboot after opting in. Existing administrator files take
precedence; inspect them instead of assuming the example replaced them.
Only remove an administrator file that you created for this test when
reverting the opt-in change. Updating the package preserves those files.

## Rollback validation

Source review of the 1.3/1.1.33 update found no changes in Steam launching,
graphics settings or kernel packages. Other Debian or Flatpak updates that
the reporter may have installed at the same time are unknown.

The 1.4/1.1.34 source checks, binary checks, `make verify` and local signed
archive checks passed. In a disposable Kernora guest with NetworkManager
1.52.1, the 1.3 policy was installed and parsed before upgrading to 1.4.
The upgrade removed the vendor file and its effective configuration section,
while keeping the inactive example. A second upgrade preserved a byte-exact
administrator override. Default and explicit saved profiles, the running
NetworkManager PID and the active Ethernet connection were unchanged.
The actual installed native Qt module loaded the corrected What's New entry
in English and Russian. Superseded automatic-enablement advice was removed
from What's New.

Logs are in `out/test-logs/cs2-network-rollback/`. No RTL8852CE radio or real
CS2 connection was available for testing. Successful rollback installation
is not evidence that the packet loss is resolved; that needs comparison on
the reporter's machine after reboot.

The rollback was published through the existing signed APT channel, archive
commit `55f9c3d4ecd9e3087605859600909009f83055e5`, with GitHub Pages reporting
a successful build. The public InRelease signature, Packages digest and
downloaded package bytes verified against the tested artifacts. The existing
guest APT client accepted the public signature and selected 1.4/1.1.34 at
priority 900. The existing
`v1-ember-5` release has corrected notes and 1.4/1.1.34 package attachments;
GitHub's asset digests match the local packages. No release or tag was created.
The original ISO is unchanged. Implementation commit: `3926e85`.

| Rollback package | SHA256 |
| --- | --- |
| kernora-base 1.4 | `ce3737841b63d7a23082a7f2da0e7fc5793175a24e787f308a133573c987ef19` |
| kernora-apps 1.1.34 | `5f601718cf5df8c9b9d6c9b30f6041fdebcd1b26dac5e9000eb92e74452ed883` |

## Historical 1.3 implementation and validation

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

On 1.3, an empty administrator override with the same filename masks the
vendor file. Do not overwrite an existing administrator policy; upgrading
to 1.4 removes the vendor default while preserving administrator files.
For a new empty override:

```sh
sudo cp --no-clobber /dev/null /etc/NetworkManager/conf.d/20-kernora-rtl8852ce.conf
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
