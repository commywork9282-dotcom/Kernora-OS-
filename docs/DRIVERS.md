# Drivers

AMD and Intel graphics work with the kernel's own drivers and the firmware the
image ships. NVIDIA cards need NVIDIA's driver. Kernora installs it by itself,
and only on computers that have an NVIDIA card.

## What gets installed

`/usr/libexec/kernora-drivers` (kernora-desktop) looks at `/sys/bus/pci/devices`
for an NVIDIA display controller (vendor `0x10de`, class `0x0300` or
`0x0302`). It takes the highest device ID it finds:

| PCI device ID | Cards | Driver |
| --- | --- | --- |
| `0x1e00` and up | GeForce GTX 16, RTX 20 and newer, RTX 50 included | `nvidia-open` from NVIDIA's Debian 13 repository |
| `0x1340` to `0x1dff` | GeForce GTX 900 and 10 | `nvidia-driver` from Debian `contrib non-free` |
| below `0x1340` | older cards | none; they stay on nouveau |

Without an NVIDIA card the tool stops after reading sysfs: no sources are added
and nothing is downloaded.

NVIDIA's repository (`developer.download.nvidia.com/compute/cuda/repos/debian13/x86_64/`)
is added only when it is needed. Its key ships in kernora-desktop
(`/usr/share/kernora/nvidia-archive-keyring.gpg`, fingerprint
`0218 2E60 104F CDC2 6EAE 1B85 97A5 D4CB 8793 F200`). Debian 13 has no driver
for RTX 50 cards, and NVIDIA's repository no longer carries the 580 branch that
GTX 900 and 10 need. Hence the two sources.

`/etc/apt/preferences.d/kernora-nvidia.pref` pins NVIDIA's repository to 100,
and its NVIDIA packages (`*nvidia*`, `libcuda*` and the like) to 600. NVIDIA
also publishes `dkms`, for example, and that stays Debian's.

After `apt-get install`, the tool checks that DKMS built `nvidia.ko` for every
kernel with headers. It then writes
`/etc/modprobe.d/kernora-nvidia.conf` (`nvidia-drm modeset=1 fbdev=1`),
regenerates the initramfs and cleans the APT cache. If any step fails, the
driver is purged again and the computer keeps using nouveau.

## When it runs

- **Installer.** `shellprocess@drivers` runs `kernora-drivers install --target`
  in the new system after the update step, when the computer is online.
- **Installed system.** `kernora-drivers.timer` starts the check 90 seconds
  after it is activated: at boot, or right after kernora-desktop is installed.
  It repeats the check every six hours. The check installs the driver in the
  background; the update notifier says so, and asks for a restart when the
  driver is ready (`/run/kernora-driver-ready`).
- **Settings › System › Drivers.** Shows the card, the driver's state and
  version, and installs or removes the driver through `pkexec` (polkit action
  `org.kernora.drivers`, which starts `kernora-drivers@install` or
  `@remove`).

The automatic check skips:

- the live session;
- computers with Secure Boot on (the DKMS module would not load until its key
  is enrolled);
- a driver the user removed in Settings;
- a failed attempt, for a day.

`automatic=false` in `/etc/kernora/drivers.conf` (the switch in Settings) turns
the automatic install off.

State lives in `/var/lib/kernora/drivers/state`: `installing`, `installed`,
`failed`, `offline`, `secureboot`, `removing` or `removed`, plus the device,
its name from `pci.ids` and the time.

## Testing without the hardware

QEMU has no NVIDIA card, so a test VM shows the tool a fake device:

```sh
mkdir -p /tmp/fakepci/0000:01:00.0
echo 0x10de > /tmp/fakepci/0000:01:00.0/vendor
echo 0x2f04 > /tmp/fakepci/0000:01:00.0/device
echo 0x030000 > /tmp/fakepci/0000:01:00.0/class
mount --bind /tmp/fakepci /sys/bus/pci/devices
```

The driver installs and DKMS builds the module. The system still boots
normally, because without the card the module never loads.

## VLC on NVIDIA

VLC 3 draws video through XWayland, and with the NVIDIA driver its hardware
decoding (VDPAU/VA-API) shows green bars along the bottom of videos. So on
PCs where the `nvidia` module is loaded, the session script
`/etc/xdg/plasma-workspace/env/kernora-video-decoding.sh` adds
`avcodec-hw=none` to VLC's config once, for the Debian VLC
(`~/.config/vlc/vlcrc`) and the Flathub one
(`~/.var/app/org.videolan.VLC/config/vlc/vlcrc`). If you already picked a
decoder yourself it's left alone, and a marker in
`~/.local/state/kernora/vlc-decoding/` makes sure it never overrides a later
change in VLC's preferences. Without an NVIDIA driver nothing happens.
