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
3. runs `waydroid init -f -s VANILLA|GAPPS`, which downloads the system and
   vendor images from Waydroid's OTA server and checks their SHA-256;
4. sets `persist.waydroid.multi_windows=true` in `waydroid.cfg` and runs
   `waydroid upgrade -o`, so apps open in separate windows;
5. enables `waydroid-container.service`.

Progress goes to `/var/lib/kernora/android/state`
(`status`, `kind`, `progress`, `time`), and `kernora-android status` prints it
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

## Starting Android

Android does not run all the time. It starts the first time an Android app
is opened and keeps running until the user stops it in Settings or logs out.

kernora-desktop diverts `/usr/bin/waydroid` to `/usr/bin/waydroid.waydroid`
and puts a wrapper in its place. For `app launch`, `app install`,
`app intent`, `app remove` and `show-full-ui` the wrapper first runs
`/usr/libexec/kernora-android-session`, which:

- starts the user service `kernora-android.service`
  (`waydroid session start`, `Type=dbus`, `BusName=id.waydro.Session`,
  part of `graphical-session.target`);
- waits until `sys.boot_completed` is `1`, at most five minutes, showing a
  "Starting Android" notification unless `KERNORA_ANDROID_QUIET` is set.

Without the wait, `waydroid app launch` right after the session starts is
lost: the session's D-Bus name appears long before Android has booted.
The first boot takes about 100 seconds in a VM with software rendering;
later boots about 40.

Waydroid writes `~/.local/share/applications/waydroid.<package>.desktop`
for each app with a launcher activity while the session runs, and hides
LineageOS' own apps. Its own `Waydroid.desktop` and its APK handler
`waydroid.app.install.desktop` are diverted too; Kernora ships a hidden
`Waydroid.desktop` named Android in their place.

Graphics: Waydroid uses the first render node that is not NVIDIA's. On a
computer with only an NVIDIA card, or in a VM without one, Android renders
in software (SwiftShader).

## Installing an app

`.apk` files open in **Android App Installer** (`kernora-apkinstaller`,
`application/vnd.android.package-archive` in `/etc/xdg/mimeapps.list`). It
reads the file itself (`src/system/apk.cpp`) before anything is installed:

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

Settings lists the installed Android apps, opens them and opens Android's
own settings app. Uninstalling goes through Android's own dialog
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
