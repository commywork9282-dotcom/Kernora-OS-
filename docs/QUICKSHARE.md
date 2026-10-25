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
  `State`, `SetEnabled`, `SetVisibility`, `SetHighVisibility`,
  `SetDeviceName`, `SetDownloadFolder`, `SetAskNearby`, `StartDiscovery`,
  `StopDiscovery`, `Send`, `Accept`, `Decline`, `Cancel`, `Dismiss`, and a
  `Changed(state)` signal with the whole state as JSON (at most four times a
  second). Off (`SetEnabled false`) stops rqs_lib completely: no listening,
  no mDNS, no Bluetooth scanning.
- incoming requests are normal notifications with Accept / Decline and the
  PIN, progress goes through Plasma's job view, the finished notification
  has the files (or Open / Copy for a link, Connect for a Wi-Fi network)
- settings live in `~/.config/kernora/quickshare.json`

It starts at login (`/etc/xdg/autostart`) and by D-Bus activation.

The UI bits are in `kernora-apps` and `kernora-desktop`: the `QuickShare`
singleton in `org.kernora.system`, Settings > Quick Share, the send window
`kernora-share` (Files opens it from the menu and the selection toolbar) and
the Quick Share tile in quick settings.

## Looks like ChromeOS

The flow and the wording follow Quick Share on a Chromebook (taken from
Chromium: `ash/system/nearby_share/`, `chrome/app/nearby_share_strings.grdp`,
`chrome/browser/resources/chromeos/nearby_share/` and
`nearby_notification_manager.cc`), the mechanics are ours.

- Quick settings tile: the icon turns Quick Share on and off, the tile opens a
  panel with the symbol, "Ready to receive" and the name you appear as, then
  Everyone / Everyone for 10 minutes (with a countdown) / Hidden, and Send and
  receive, which opens the app. The sublabel is Off, Hidden, Everyone or
  "Everyone, 9 min". ChromeOS has "Your devices" and "Contacts" where we have
  "Everyone", those need a Google account.
- Sending from Files is ChromeOS's two steps: select the device next to a
  preview of what you share (thumbnail for a single image), then "Share with
  this device?" with the device in a progress ring and "Secure connection
  ID". The window closes as soon as the transfer starts, progress goes on in
  notifications. A decline shows "Can't share / The device you're trying to
  share with did not accept".
- Notifications: "Receive with Quick Share?" / "Pixel is sharing an image
  with you." + the secure connection ID, Accept and Decline; progress
  "Receiving an image from Pixel" with Cancel; "Image received from Pixel"
  with Open folder (and Copy to clipboard for one image, through wl-copy);
  "Failed to send ... to ..."; "Device nearby is sharing / To receive and
  accept files with people around you, become visible" with Enable and
  Dismiss. Items are named like ChromeOS does: an image, 3 files, a video, a
  link, text.

## Looks like Android too

`kernora-share` is also the Quick Share app in the app menu, laid out like the
Android one with M3 Expressive bits: a big title and Receive / Send at the
bottom.

- Receive: "You'll appear as" with the name (rename right there) and who can
  see you, "Sharing with you" with the Quick Share symbol in a slowly spinning
  cookie shape and "Ready to receive". When a phone shares something it shows
  up in the same card with the connection ID and Accept / Decline, then the
  progress and Open folder. Like Android, opening Receive while hidden makes
  the computer visible to everyone for a while, closing the window hides it
  again (unless you picked the visibility yourself).
- Send: choose files or drop them on the window, the devices are a grouped
  list with shaped avatars; Done when it's sent. Opening Quick Share from
  Files while the app is open reuses the window.

The symbol (a ring made of two arrows) isn't part of Material Symbols, Google
only has it as the Quick Share logo. `tools/draw-symbols` in kernora-desktop
draws our own version in the Material Symbols Rounded style (960 grid, 80
units stroke, round caps) plus a filled one; it needs skia-pathops and only
runs when the drawing changes, the SVGs are kept in `data/symbols` and the
lock like the upstream ones. The shapes (cookie, clover, sunny...) are the
Material 3 shape set from `MShape` in `org.kernora.m3`.

## Visibility

- **Hidden** (the default): nobody sees the computer. When a phone nearby
  opens Quick Share, its Bluetooth advert is picked up and a notification
  offers to become visible. It works like ChromeOS's "Device nearby is
  sharing": one notification per time a phone shares, it goes away by itself
  about 30 seconds after the phone stops, Dismiss (or closing it) keeps it
  quiet for 15 minutes, and Don't ask again turns it off for good (Settings >
  Quick Share > Ask when a device nearby is sharing brings it back). Only
  real Quick Share adverts count, see the patches below.
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
- Listening for "someone nearby is sharing" is a Bluetooth LE scan, and it
  only runs while that prompt can actually show up: Quick Share on, hidden,
  and Ask when a device nearby is sharing on. Visible to everyone or the
  prompt off means no scan. Cards that do Wi-Fi and Bluetooth on one chip
  share the radio, so a scan that never stops can cost Wi-Fi time; if Wi-Fi
  acts up on such a card, turning the prompt off (or Bluetooth) is a quick
  way to tell whether it's that.

## Safety

rqs_lib writes an incoming file to `download folder + name`, with the name
as the sender gave it. The daemon declines any transfer whose names contain a
`/`, are empty, `.` or `..`, before the request is even shown, so a sender
can't write outside the download folder. "Open" for links only works for
http and https.

## Patches to rqs_lib

`patches/rqs_lib.patch` is applied to the vendored copy:

- the nearby Bluetooth listener isn't started by `run()` any more, the
  daemon turns it on and off with `set_nearby_listener()`, and stopping it
  stops the bluez scan too (upstream left the discovery running).

- the Bluetooth listener only reacts to Quick Share's own advert: service
  0xFE2C with the model ID FC 12 8E, like ChromeOS's fast initiation
  scanner. Upstream took anything on 0xFE2C, and that's Google Fast Pair
  too, so earbuds, watches and phones nearby set off "someone nearby is
  sharing" all day. It also stops the listener from dying when the clock
  jumps back.
- no Bluetooth adapter (nothing in `/sys/class/bluetooth`), no BLE at all.
  Upstream asks bluez anyway and the D-Bus activation hangs for 25 seconds
  at every start and every rename, with the computer invisible meanwhile.
  The BLE listener also starts in the background now, not inline.
- discovery picks the other device's address that is in one of our own
  subnets, instead of a random one (and skipping the device when the random
  one happened to be ours). Matters with docker, VPNs or two network cards.
- sending doesn't power Bluetooth on (`set_powered(true)` is gone).
- a failed outbound connect (refused, unreachable, 10 s TCP timeout) is
  reported as Disconnected. Upstream only logs it, and the sender would sit
  on Connecting forever.

`patches/btleplug.patch` makes btleplug ask bluez for LE discovery instead
of "auto". Auto also runs classic inquiry in a loop, which Quick Share never
needs and which is the heavy part next to Wi-Fi.

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
