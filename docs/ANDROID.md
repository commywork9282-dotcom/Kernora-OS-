# Android apps

Kernora runs Android apps with [Waydroid](https://waydro.id): a full Android
system (LineageOS 20, Android 13) in an LXC container that draws its windows
straight onto the Plasma Wayland session. Every Android app gets its own
window, sits in the launcher with the other apps and shows its icon in the
dock. This is a demo feature: it is published to the `ember-demo` channel
only.

## Turning it on

Nothing Android is installed until the user asks for it in
**Settings › Android apps**. The page offers two images as a radio list;
Google Play comes first, is marked as recommended and is picked by default:

| Choice | Image | Download | On disk |
| --- | --- | --- | --- |
| Google Play and APK files (recommended) | `GAPPS` | about 1.4 GB | about 3 GB |
| APK files only | `VANILLA` | about 1 GB | about 2.3 GB |

`Set up` runs `pkexec /usr/libexec/kernora-android request setup-vanilla`
(or `setup-gapps`; polkit action `org.kernora.android`). The request starts
`kernora-android@setup-vanilla.service`, which runs as root:

1. adds `/etc/apt/sources.list.d/kernora-android.sources` with Debian's
   `trixie-backports` (Waydroid, libgbinder, libglibutil and python3-gbinder
   are not in trixie itself; backports are pinned at 100 by Debian, so only
   packages that exist nowhere else come from there);
2. refreshes that source on its own, so a broken unrelated source does not
   stop the setup, and installs `waydroid` without recommends (with them
   `lxc` drags in distrobuilder, qemu-utils and some 40 more packages);
3. downloads the system and vendor images with
   `/usr/libexec/kernora-android-fetch setup VANILLA|GAPPS` (below), then runs
   `waydroid init -f -s VANILLA|GAPPS`, which finds them already in place;
4. sets `persist.waydroid.multi_windows=true` in `waydroid.cfg` and runs
   `waydroid upgrade -o`, so apps open in separate windows;
5. enables `waydroid-container.service`.

Waydroid's own download takes one SourceForge mirror and stays on it; a slow
mirror made the setup take hours. `kernora-android-fetch` reads the same OTA
channel (`ota.waydro.id`, or `/usr/share/waydroid-extra/channels.cfg`), asks
SourceForge for a mirror a dozen times to collect up to six of them, and
downloads the zip in 4 MiB parts over two connections per mirror. A
connection that is idle takes over the rest of a part from a slower or silent
one (silent for 3 s counts as stuck), a mirror eight times slower than the
best one stops taking parts, and dead mirrors are dropped and looked up
again. The zip has to match the SHA-256 from the channel; then `system.img`
and `vendor.img` are unpacked into `/var/lib/waydroid/images` and the channel
URLs and image dates go into `waydroid.cfg`. Since `waydroid init` keeps the
dates when the channel URL is the same and only downloads newer images, it
downloads nothing. If the quick download fails, `waydroid init` downloads the
images itself as before. It prints `progress DONE TOTAL SECONDS_LEFT`, which
Settings shows as the time left.

Progress goes to `/var/lib/kernora/android/state`
(`status`, `kind`, `progress`, `remaining`, `bytes`, `bytes_total`, `time`),
and `kernora-android status` prints it together with what is installed, the
image size, whether a job runs and the Google state (below). The percentage
covers the whole setup, so it moves from the first second: Waydroid's own
packages 0–12 % (apt's `APT::Status-Fd` download and install progress), the
images 12–92 %, unpacking and the first `waydroid init` up to 100 %. The
download can be cancelled (`request cancel`); a cancelled or failed download
leaves no image behind. The live session refuses the setup.

When the setup ends, `kernora-android` writes `/var/lib/kernora/android/done`
(`status`, `kind`, `time`). The user path unit `kernora-android-done.path`
runs `kernora-android-session --done`, which shows a notification once per
setup ("Android apps are ready", or that it failed) and opens
**Settings › Android apps** when it is clicked.

`Remove Android` (`request remove`) stops the container, purges `waydroid`
with the packages it brought, deletes `/var/lib/waydroid` and, for every
user, `~/.local/share/waydroid` and the `waydroid.*.desktop` entries. That
data belongs to Android's own users, so a normal user cannot delete it.

The Debian kernel has binder as a module (`binder_linux`, no binderfs).
Waydroid loads it with its own device names (`anbox-binder` and so on) and
remembers them in `waydroid.cfg`; Kernora does not set module options, so the
names never disagree after a reboot.

## Opening an app

Users see apps, not a second system: nothing in the interface names
Waydroid, nothing "starts Android", and Android's own launcher and settings
are not offered. Nothing is locked either: the `waydroid` command keeps
working in a terminal.

The Android runtime starts the first time an Android app is opened (or at
sign-in with **Open apps faster**, which enables the user unit) and runs
until the user logs out.

kernora-desktop diverts `/usr/bin/waydroid` to `/usr/bin/waydroid.waydroid`
and puts a wrapper in its place. For `app launch`, `app install`,
`app intent`, `app remove` and `show-full-ui` the wrapper first runs
`/usr/libexec/kernora-android-session`, which:

- starts the user service `kernora-android.service`
  (`waydroid session start`, `Type=dbus`, `BusName=id.waydro.Session`,
  part of `graphical-session.target`);
- waits until `sys.boot_completed` is `1` and the session has logged
  "Android with user 0 is ready" (the launch is lost in the two seconds
  between them), at most five minutes. Waydroid does not always get the
  unlock event (it missed it on a first boot with Google Play), so three
  seconds after `sys.user.0.ce_available` turns `true` count as ready too.

When an app is opened while the runtime is not up, the wrapper shows
`kernora-appsplash`: a frameless card with the app's own icon and name and
the Expressive loading indicator. The splash takes the app's desktop file
name (`waydroid.<package>`), so the dock shows the app's icon from the
first moment; it fades out 1.5 seconds after the launch.

Waydroid writes `~/.local/share/applications/waydroid.<package>.desktop`
for each app with a launcher activity while the session runs, and hides
LineageOS' own apps. Its own `Waydroid.desktop`, its APK handler and its
`market://` handler are diverted; Kernora ships hidden entries without the
Waydroid name in their place, plus hidden entries with the Kernora icon for
the windows Android opens by itself (permissions, the package installer,
Google sign-in, system dialogs).

## Looking like Kernora

`tools/gen-android-overlay` builds `KernoraCaption.apk` when the package is
built: a static resource overlay for `android`, written without aapt (its
own binary XML and resource table) and signed (APK v1, `openssl smime`)
with AOSP's public platform test key, which the Waydroid images are signed
with (`userdebug/test-keys`). The platform signature lets it replace any
framework resource. It gives the caption that Android draws over every app
window the Kernora title bar: the Material surface container colour,
Material Symbols Rounded for back, minimise, maximise and close, and the
pressed circles of the Kernora decoration (Waydroid takes the pointer over
the caption to move the window, so there is no hover). The setup and every
package update copy it to
`/var/lib/waydroid/overlay/system/product/overlay/KernoraCaption/`.

`/usr/libexec/kernora-android-sync` (polkit `org.kernora.android.sync`,
allowed for the active user without a password) runs inside Android with
`waydroid shell`:

- `settings put secure theme_customization_overlay_packages` with the
  Kernora seed (`seed=` in `/usr/share/kernora/palettes/<colour>.conf`) as
  a preset Material You palette, so Android's system colours and every
  Material You app take the Kernora colour; Grey uses `SPRITZ`, the rest
  `TONAL_SPOT`;
- `cmd uimode night yes|no` from the light or dark Kernora scheme (the
  `ui_night_mode` setting alone is only read at boot);
- writes `pm list packages -s` to
  `/var/lib/kernora/android/system-packages`; the user side then hides the
  desktop entries of those packages, except the Play Store;
- disables `org.lineageos.waydroidupdater`, whose notifications would talk
  about Waydroid.

It runs from `kernora-android.service` once Android is up, and from the user
path unit `kernora-android-sync.path` whenever `kdeglobals`, `kernorarc` or
`kwinoutputconfig.json` change.

Scale and size: the sync also sets Android's density to 160 × the scale of
the main screen (`kscreen-doctor -j`), so Android apps are as big as the rest
of Kernora. Android 13 gives a new freeform window a phone-sized default
(412×732 dp), which made apps look like phone apps on the desktop.
Windows keep the size Android gives them. Resizing a window after the app
started (1.4.58–1.4.62 widened every new window to about 72 % of the
screen) is a configuration change: Unity games lost their surface
("Timeout while trying detaching primary window") and died, logins reset
and windows jumped through several sizes. Android remembers the size per
app when the user resizes a window. `kernora-android-windows` (root
through the polkit action `org.kernora.android.windows`, started after
boot) now only runs with more than one monitor: a new window that Android
put across two monitors is moved, at its size, onto the main monitor
(`am task resize` with the same width and height; a pure move does not
restart the app). A window that fits on any monitor is left alone.

Only apps: the sync also turns off Android's built-in on-screen keyboard
apps (`pm disable-user` for every system package in `ime list -s -a`, plus
`show_ime_with_hard_keyboard 0`), so the physical keyboard types into the
app and no "InputMethod" window opens. `ime disable` alone was not enough:
Android turns a system keyboard back on whenever none is enabled, after
every restart of its system. Keyboards the user installs are left alone.
It also hides
nothing about Android's "isn't responding" dialog (`hide_error_dialogs 0`:
with 1, Android killed an app at once on every ANR, and right after boot
Google Play, the Google app and others hit ANRs and vanished; instead
`ro.hw_timeout_multiplier=3` gives slow computers and virtual machines
three times Android's usual ANR timeouts, as Android's emulators do);
and keeps the device set up (`device_provisioned`, `user_setup_complete`)
with Google's and LineageOS's setup wizards and the LineageOS updater
disabled, so nothing asks to finish setting up the device. Windows of
Android's keyboard, Settings search, setup and speech services get hidden
desktop entries with the Kernora icon.

Keyboard layouts: Waydroid hands Android raw key codes, so Android typed
with its own US English layout whatever Kernora used. Once Android is up,
`kernora-android-session --keyboard-follow` reads Plasma's layouts
(`org.kde.keyboard`), maps the current one to Android's (`us` →
`english_us`, `ru` → `russian`, … with a few variants) and has
`kernora-android-keyboard` (root through polkit
`org.kernora.android.keyboard`) set it for Waydroid's keyboard
(`vendor:1,product:1`) through the input service: `service call input 18`
is `setCurrentKeyboardLayoutForInputDevice` and `21` is
`removeKeyboardLayoutForInputDevice` in Android 13's `IInputManager`, so
the helper does nothing on another SDK. Android keeps only the current
layout, so Ctrl+Space inside an app has nothing to switch to. It runs again
on every `layoutChanged`/`layoutListChanged`. Ctrl+Space through
`/dev/input/wl_keyboard_events` is not used: Android answers it with a
toast window, and a toast while Android's graphics are down (Waydroid's
composer aborts when KWin stalls for a few seconds) brings down
system_server.

ARM apps: most apps on Google Play ship native code only for ARM, and
Android refused them (`INSTALL_FAILED_NO_MATCHING_ABIS`; Play hides them).
`kernora-android-device arm-download` fetches a translator for the
processor from pinned archives of the supremegamers mirrors (the same ones
waydroid_script uses), checked by SHA-256: Google's `libndk_translation`
from ChromeOS (zork) on AMD and Hygon, whose licence limits it to AMD
processors, and Intel's `libhoudini` 14 from Google Play Games on Intel.
Both are proprietary. `arm-install` copies `prebuilts/` into
`/var/lib/waydroid/overlay/system` without `etc/init` and
`etc/binfmt_misc`: the container shares the host's binfmt_misc, so those
rules would take over ARM executables on the host (qemu-user, docker
buildx). Apps load ARM libraries through the native bridge; an app that
executes a bare ARM program still fails. With the translator installed the
helper adds `ro.product.cpu.abilist*`, `ro.dalvik.vm.isa.arm*` and
`ro.dalvik.vm.native.bridge` to `waydroid.cfg`; Waydroid's prop file
overrides the system `build.prop` here, no resetprop needed. The setup
downloads it after the image (progress 93–96 %); Android apps that are
already set up get it from `kernora-android-update.service`, and it is
installed while Android is stopped. `kernora-android status` reports
`arm=yes|no|unsupported`, and the APK installer takes ARM-only APKs when it
is `yes`.

Graphics: Waydroid skips NVIDIA render nodes and uses the first other one,
and only when `init`/`upgrade` runs. With the screen on an NVIDIA card and
an integrated GPU in the machine, Android drew on the integrated GPU and
KWin on the NVIDIA card showed black windows; a computer set up before
Kernora installed the NVIDIA driver kept pointing at the nouveau node.
`kernora-android-device` treats the card with `boot_vga=1` (or else the one
with a connected output) as the screen's card. If its driver is nvidia or
nouveau, or there is no other render node (a `virtio_gpu` without the virgl
bit in its virtio `features` counts as none; with virtio-vga the DRM device
is the PCI device, driver `virtio-pci`, and the bit is in
`device/virtio*/features`), Android draws in software:
`ro.hardware.gralloc=default`, `ro.hardware.egl=swiftshader`,
`ro.hardware.vulkan=pastel`. Before every start of Android,
`kernora-android.service` runs `kernora-android-refresh` (polkit
`org.kernora.android.refresh`, allowed for the active user), which installs
a downloaded translator, writes the properties and runs `waydroid upgrade
-o` when they differ from `waydroid_base.prop`. The keys Kernora set are
kept in `/var/lib/kernora/android/properties` (updated only after a
successful upgrade), so keys that no longer apply are taken out again and
keys the user added stay.

## Windows

Android apps work the way they do on a Chromebook: Android runs the app, the
desktop owns the window.

Waydroid's hwcomposer is a Wayland client. Each Android task is one
see-through toplevel the size of the whole Android screen, every Android
layer is a subsurface at its Android position, and solid colour layers are
dropped. Left alone that gives an Android title bar drawn over the app,
windows that can only move inside Android, and see-through holes.

`kernora-android-display` (user service, Python, about 1% of one core while a
video plays) sits between the hwcomposer and KWin. `waydroid session start`
runs with `WAYLAND_DISPLAY=kernora-android-0`, so the hwcomposer connects to
it, and it translates every object id on the way to the real socket; that is
why it needs `wayland-protocols.json`, the message signatures of the
protocols the hwcomposer uses. On top of plain forwarding it:

- asks KWin for server-side decorations, so the title bar, buttons, shadow,
  snapping and the move itself are KWin's. Android does not hear about moves.
- sets the window geometry to the rectangle the app's layers cover, so KWin
  sees a window of the app's size, not of the Android screen.
- puts an opaque black surface under the app, in place of the layers the
  hwcomposer drops.
- holds back the first buffer until the app has a layer and
  `kernora-android-windows` has given the app its size, so KWin places a
  window of the right size and an empty frame never appears. The helper says
  so on the `kernora-android-ready` pipe; without it the window shows after
  2.5 s.
- answers KWin's size changes itself and passes 0x0 to the hwcomposer, which
  would otherwise treat them as a new Android screen size. While the mouse
  is down the frame follows at once; on release one line goes to the
  `kernora-android-resize` pipe.

Android's own window chrome is switched off in three places.
`persist.wm.debug.caption_on_shell=true` removes the caption apps draw inside
their window, which also pushed Unity's surface out of place. `KernoraShell.apk`,
a static overlay on SystemUI, makes the shell's caption 1 px tall and its
resize handles zero wide. Zero height is not an option: the caption window
then gets a touchable region as large as the task and swallows every click.
The handles matter because their corner squares reached 22 dp into the app
and ate clicks there. Esc is Android's Back, which replaces the caption's
back arrow.

`kernora-android-windows` (root, started after boot) applies the rest:

- `arrange()` keeps every task's top-left corner off every other task.
  SurfaceFlinger leaves a fully covered layer out, and the hwcomposer closes a
  window with no layers, so a maximized app used to close whatever was behind
  it. Tasks sit on a small diagonal, smallest first, which is why the Android
  screen is 64 px larger than the largest monitor. Android positions have no
  meaning on the desktop.
- `resize()` turns requests from the pipe into `am task resize`.
- `open_large()` gives a resizable app with no fixed orientation a tablet-sized
  window the first time it opens, before it has laid itself out. Apps pick
  their layout when they start, and YouTube kept its phone layout, stretched,
  when it was maximized later. Android remembers the size from then on, in
  `/data/system_ce/0/launch_params`.
- `reshape()` turns a window round when an app asks for the other orientation.
  In a window of the wrong shape Android letterboxes it into a flat strip.

Android's screen is sized by `kernora-android-device` from the outputs in
`/var/lib/kernora/android/screens` (from `kscreen-doctor -j`, written by
`kernora-android-session --prepare`). A window can go to any monitor because
KWin moves it.

KWin's first configure is often 1 px off the app's size, so differences of
2 px or less are not treated as a resize.

## Updates

The `waydroid` package and its libraries update with the system from
trixie-backports. The image updates itself: `kernora-android-update.timer`
runs `kernora-android update` daily; when Waydroid's OTA channel has a newer
system or vendor image, `kernora-android-fetch download` gets it the same
quick way into `/var/lib/waydroid/cache_http` even while apps are open. Once
no app is open, `kernora-android-fetch install` puts it in place and
`waydroid upgrade -o` finishes the job (the properties in `waydroid.cfg` and
the overlay stay); Settings shows "Updating…" meanwhile. A downloaded image
waits for the next run if an app is open, and is not downloaded again.
Setting up or removing Android apps stops a running update first.

## Installing an app

`.apk` files open in **Android App Installer** (`kernora-apkinstaller`,
`application/vnd.android.package-archive` in `/etc/xdg/mimeapps.list`), a
frameless dialog laid out like Android's own installer: the current step on
top ("Install this app?", "Installing…", "App installed"), the app icon, name
and version in the middle, a short reason only when something is wrong, and
a tonal and a filled button at the end. Files shows each APK with the
app's own icon (`Android.iconOf`, read in a worker thread and cached). The
installer reads the file itself (`src/system/apk.cpp`) before anything is installed:

- the ZIP central directory, so APK signature blocks do not get in the way
  (KZip reads entries in order and stops at the signing block);
- the binary `AndroidManifest.xml` for the package name, version and
  `minSdkVersion`;
- `resources.arsc` for the label in the user's language and the icon;
- the icon: an adaptive icon is drawn in a circle from its layers (colours,
  bitmaps, `inset`, `layer-list`, `shape` and vector drawables, which are
  turned into SVG with their gradients), otherwise the best bitmap;
- `lib/<abi>` folders: an app with native code only for ARM cannot run on
  the x86_64 image, so the installer says so instead of failing.

The installer then starts Android if needed and runs `waydroid app install`.
It checks `waydroid app list` afterwards, because the command exits 0 even
when Android refuses the package. The command also returns before Android
has finished installing, so the installer asks again every 2 seconds for up
to a minute; a big app like Termux takes several seconds.

Settings lists the user's Android apps and opens them. Uninstalling goes
through Android's own dialog
(`waydroid app intent android.intent.action.DELETE package:<name>`):
`waydroid app remove` fails with code -3 on the LineageOS 20 image and still
exits 0. The list follows the `waydroid.*.desktop` files, which Waydroid
deletes when the package goes. With the
Google Play image it shows two steps until a Google account is signed in.
"Register this computer" uses the Google Services device ID that the sync
keeps in `/var/lib/kernora/android/google` (with the number of Google
accounts); if there is none yet, `kernora-android-session --google` starts
Android and waits for it. Settings copies the ID and opens
`google.com/android/uncertified`. "Sign in to Google Play" restarts Android
once after registering, so Google Play sees the change, and opens the Play
Store.

## What does not work

- Fixed-size games show black bars when their window is made larger than
  the game.
- Plasma on X11. Waydroid needs a Wayland compositor, so `waydroid session
  start` exits at once and no Android app opens. `kernora-android-session`
  notices this before starting the session, shows a notification, and on a
  click sets SDDM's last session to Plasma on Wayland and asks to sign out.
  Settings and the APK installer say the same thing.
- Apps that check for a certified device: banking apps, some streaming apps,
  games with anti-cheat.
- App bundles (`.xapk`, `.apks`, `.aab`); only single APK files install.
