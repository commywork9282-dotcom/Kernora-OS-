# Realtek RTL8852CE Wi-Fi

Someone reported their RTL8852CE Wi-Fi dropping randomly. This page is what
I tried so far and how to help debug it.

## Where it's at (kernora-base 1.4)

In 1.3 I added an automatic tweak that turned off Wi-Fi power saving for this
card. After that update the tester saw packet loss and lag spikes in CS2.
Nothing proves the tweak caused it, but I couldn't rule it out either, so 1.4
rolls it back. The original disconnect problem is still open.

Update to `kernora-base` 1.4 and `kernora-apps` 1.1.34 and **reboot**. The
update removes the old file from `/usr/lib/NetworkManager/conf.d`, reloads the
config and that's it: it doesn't restart the network, touch your saved
connections, remove your own config files or change Steam/CS2 launch options.
Reboot anyway cause removing a config default doesn't reset a radio that's
already running.

This is to compare, not a fix. If you still get packet loss after a reboot,
try the same thing over Ethernet on the same PC, and grab the kernel log
after a spike with the command further down. Lost packets on the game server
or your internet route, on the local Wi-Fi, or frame stalls all look similar
in game but need different fixes.

## Turning the tweak on yourself

The old tweak is still installed as an example at
`/usr/share/kernora/workarounds/20-kernora-rtl8852ce.conf`. It's outside of
NetworkManager's config folders so it does nothing by default. If you want to
try it:

```sh
sudo cp --no-clobber /usr/share/kernora/workarounds/20-kernora-rtl8852ce.conf /etc/NetworkManager/conf.d/
sudo nmcli general reload conf
```

Reconnect or reboot after. If you already had your own file with that name
it wins, `--no-clobber` won't overwrite it. To undo, delete the file you
copied. Updates never touch files in `/etc/NetworkManager/conf.d`.

## What the tweak does

It only matches the in-kernel `rtw89_8852ce` driver (PCI ID `10ec:c852`) and
sets `wifi.powersave=2` (off) as the default. Connections that have power
saving set to anything other than default (`1`, `2`, `3`) keep their value,
and other Wi-Fi cards and Ethernet aren't affected. Turning power saving off
can use a bit more battery. The ISO already has `firmware-realtek` and a
supported driver, nothing else gets replaced.

## Checking your card

To see which card and driver you have (`lspci` comes with kernora-base
1.6.3, older installs can use the `nmcli` line):

```sh
lspci -nnk | grep -iA3 network
nmcli -f GENERAL.DEVICE,GENERAL.DRIVER device show
```

After reconnecting:

```sh
nmcli -f GENERAL.DEVICE,GENERAL.DRIVER device show
/usr/sbin/iw dev
/usr/sbin/iw dev INTERFACE get power_save
```

Replace `INTERFACE` with the Wi-Fi interface from `/usr/sbin/iw dev`. With the tweak on
and a default profile you should see `Power save: off`. Then test idle, a
big download, and suspend/resume, whatever used to make it drop.

If a connection has power saving set explicitly:

```sh
nmcli -g 802-11-wireless.powersave connection show uuid UUID
```

`UUID` comes from `nmcli connection show`. To make it use the system default
again: `nmcli connection modify uuid UUID 802-11-wireless.powersave 0`, then
reconnect.

## If it drops again

Before rebooting, grab this:

```sh
uname -r
dpkg-query -W firmware-realtek network-manager
sudo journalctl -k -b --since '-20 min' --no-hostname --case-sensitive=no --grep='rtw89|8852|firmware|lps|pcie|aer'
```

Look through it before sharing. Firmware errors, PCIe errors, roaming, router
auth problems and suspend issues all need different fixes, and the card model
alone doesn't tell them apart. I'm not gonna ship an out-of-tree DKMS driver,
delete firmware or turn off ASPM for everyone based on one report.

## What I tested

1.3: upgrading from 1.2 in a Kernora VM (Linux 6.12.107, NetworkManager
1.52.1). NetworkManager loaded the policy, an empty file in `/etc` masked it,
a custom one overrode it, saved profiles kept their settings and the active
connection didn't drop.

1.4: upgrading from 1.3 removed the policy and kept the example, kept a custom
admin file byte for byte, and saved profiles plus the active Ethernet
connection were untouched. What's New loads in English and Russian.

I don't have an RTL8852CE card, so none of this proves anything about the
actual radio. That needs testing on the tester's machine.

| Package | SHA256 |
| --- | --- |
| kernora-base 1.3 | `fa084678d308958aafb1128c39a8a2b400dd54045b5ef410b56cbc0039f3c605` |
| kernora-apps 1.1.33 | `5ab75a355ae323b85ee6178b06d1a6f41d0899a74eb9909084b3388126744764` |
| kernora-base 1.4 | `ce3737841b63d7a23082a7f2da0e7fc5793175a24e787f308a133573c987ef19` |
| kernora-apps 1.1.34 | `5f601718cf5df8c9b9d6c9b30f6041fdebcd1b26dac5e9000eb92e74452ed883` |

## Links

- [NetworkManager config: device matching, connection defaults, overrides](https://networkmanager.pages.freedesktop.org/NetworkManager/NetworkManager/NetworkManager.conf.html)
- [NetworkManager Wi-Fi power saving values](https://networkmanager.pages.freedesktop.org/NetworkManager/NetworkManager/settings-802-11-wireless.html)
- [In-kernel RTL8852CE driver name and PCI ID in Linux 6.12.107](https://github.com/gregkh/linux/blob/v6.12.107/drivers/net/wireless/realtek/rtw89/rtw8852ce.c)
- [rtw89 maintainer notes on optional power management workarounds](https://github.com/lwfinger/rtw89/blob/main/README.md)
