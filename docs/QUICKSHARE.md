# Quick Share

Kernora talks Google's Quick Share (ex Nearby Share), so an Android phone can
send files to the computer and the other way around, without installing
anything on the phone. Two Kernora machines can do it too.

## How it works

`kernora-quickshare` is a small user daemon in Rust. The protocol part is
`rqs_lib` from [rquickshare](https://github.com/Martichou/rquickshare), the
fork by [nozwock](https://github.com/nozwock/rquickshare) that
[Packet](https://github.com/nozwock/packet) uses, pinned to one commit in
`Cargo.lock`. The rest is ours:

- D-Bus API `org.kernora.QuickShare1` on `/org/kernora/QuickShare`: methods
  `State`, `SetVisibility`, `SetDeviceName`, `SetDownloadFolder`,
  `SetAskNearby`, `StartDiscovery`, `StopDiscovery`, `Send`, `Accept`,
  `Decline`, `Cancel`, `Dismiss`, and a `Changed(state)` signal with the
  whole state as JSON (at most four times a second)
- incoming requests are normal notifications with Accept / Decline and the
  PIN, progress goes through Plasma's job view, the finished notification
  has the files (or Open / Copy for a link, Connect for a Wi-Fi network)
- settings live in `~/.config/kernora/quickshare.json`

It starts at login (`/etc/xdg/autostart`) and by D-Bus activation.

The UI bits are in `kernora-apps` and `kernora-desktop`: the `QuickShare`
singleton in `org.kernora.system`, Settings > Quick Share, the send window
`kernora-share` (Files opens it from the menu and the selection toolbar) and
the Quick Share tile in quick settings.

## Visibility

- **Hidden** (the default): nobody sees the computer. When a phone nearby
  opens Quick Share, its Bluetooth advert is picked up and a notification
  offers to become visible.
- **Everyone for 10 minutes**: what the quick settings tile turns on.
- **Everyone**: always visible.

Visible only means the phone can *ask*. Every incoming transfer waits for
Accept.

## Things to know

- Only the Wi-Fi LAN medium is implemented. Both devices need to be on the
  same network, with mDNS not blocked. No Bluetooth or Wi-Fi Direct
  transfers.
- Bluetooth is only used to wake the phone up (BLE adverts). Without it the
  computer still works, but the phone sees it only while the phone's Quick
  Share screen is open.
- "Contacts" and "Your devices" visibility need Google account certificates,
  so it's Everyone or nothing.
- Bluetooth is never switched on by Quick Share. If it's off, phones just
  aren't woken up.

## Safety

rqs_lib writes an incoming file to `download folder + name`, with the name
as the sender gave it. The daemon declines any transfer whose names contain a
`/`, are empty, `.` or `..`, before the request is even shown, so a sender
can't write outside the download folder. "Open" for links only works for
http and https.

## Patches to rqs_lib

`patches/rqs_lib.patch` is applied to the vendored copy:

- no Bluetooth adapter (nothing in `/sys/class/bluetooth`), no BLE at all.
  Upstream asks bluez anyway and the D-Bus activation hangs for 25 seconds
  at every start and every rename, with the computer invisible meanwhile.
  The BLE listener also starts in the background now, not inline.
- discovery picks the other device's address that is in one of our own
  subnets, instead of a random one (and skipping the device when the random
  one happened to be ours). Matters with docker, VPNs or two network cards.
- sending doesn't power Bluetooth on (`set_powered(true)` is gone).

## Build

The package build is offline, so the crates are vendored.
`scripts/fetch-quickshare-crates` runs `cargo vendor --locked` in the
`quickshare` build chroot, turns crates that Linux builds never compile
(Windows, macOS) into empty stubs (`tools/stub-vendor`), and checks the
tarball against `QUICKSHARE_VENDOR_SHA256` in
`configs/upstream/quickshare.env`. `rqs_lib` pulls `sys_metrics` (AGPL-3.0)
just for the host name; `shim/sys_metrics` replaces it through `[patch]`, so
nothing AGPL ends up in the binary.

After changing `Cargo.lock`, empty the pin, run the script once to get the
new hash, pin it and run it again: the second run must give the same hash.
