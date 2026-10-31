# Android apps

Kernora runs Android apps with [Waydroid](https://waydro.id): a full Android
system (LineageOS 20, Android 13) in an LXC container that draws its windows
straight onto the Plasma Wayland session. Every Android app gets its own
window, sits in the launcher with the other apps and shows its icon in the
dock. This is a demo feature: it is published to the `ember-demo` channel
only.

## Turning it on

Nothing Android is installed until the user asks for it in
**Settings › Android apps**. The page offers two images:

| Choice | Image | Download | On disk |
| --- | --- | --- | --- |
| Android | `VANILLA` | about 1 GB | about 2.3 GB |
| Android with Google Play | `GAPPS` | about 1.4 GB | about 3 GB |

`Turn on` runs `pkexec /usr/libexec/kernora-android request setup-vanilla`
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
(`status`, `kind`, `progress`, `remaining`, `time`), and `kernora-android status` prints it
together with what is installed, the image size and whether a job runs. The
download can be cancelled (`request cancel`); a cancelled or failed download
leaves no image behind. The live session refuses the setup.

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
  between them), at most five minutes.

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
path unit `kernora-android-sync.path` whenever `kdeglobals` or `kernorarc`
change.

Graphics: Waydroid uses the first render node that is not NVIDIA's. On a
computer with only an NVIDIA card, or in a VM without one, Android renders
in software (SwiftShader).

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
frameless Material dialog in the Pixel style. Files shows each APK with the
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
when Android refuses the package.

Settings lists the user's Android apps and opens them. Uninstalling goes
through Android's own dialog
(`waydroid app intent android.intent.action.DELETE package:<name>`):
`waydroid app remove` fails with code -3 on the LineageOS 20 image and still
exits 0. The list follows the `waydroid.*.desktop` files, which Waydroid
deletes when the package goes. With the
Google Play image it also reads the Google Services device ID
(`kernora-android android-id`, root, needs Android running), copies it and
opens `google.com/android/uncertified`, where the user registers the
computer before signing in to the Play Store.

## What does not work

- Apps with native code only for ARM. Waydroid's image has no ARM
  translation.
- Apps that check for a certified device: banking apps, some streaming apps,
  games with anti-cheat.
- App bundles (`.xapk`, `.apks`, `.aab`); only single APK files install.
