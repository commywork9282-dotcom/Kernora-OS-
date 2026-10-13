# Store

Store finds graphical applications in the Debian AppStream catalogue and
Flatpak remotes. Flathub is configured by the packaged remote definition;
existing remotes and installed apps are kept. Where both formats exist,
the app page offers a source choice before installation. Existing apps use
their installed source for removal and updates.

Flatpak work runs outside the GUI thread, with progress and cancellation.
Closing the window during an installation hides it until the operation
finishes. Debian actions go through PackageKit and the session's normal
authentication agent. Local `.deb` and `.flatpakref` files open in Store;
`appstream:` links open an app page. No package is installed just by opening
a file or visiting a page.

The Installed page includes apps installed outside Store when their
metadata is available. Flatpak apps and runtimes update in Store; Debian
and Kernora updates stay in Settings. A failed update check keeps the last
known update list and displays a retry action instead of claiming success.

Descriptions and screenshots come from the repositories. Star ratings
come from ODRS, are cached for three days, and are omitted when unavailable.
Artwork is cached on disk. Without a connection the cached catalogue and
installed apps remain usable; new downloads still need a connection.

## Validation

Build and check packages using `scripts/build-kernora-apps-binary` and
`scripts/build-kernora-desktop-binary`. Their tests verify the Store module,
launcher, runtime dependencies, remote definition and Russian translation.

In a disposable Kernora desktop session with both catalogues downloaded:

```sh
KERNORA_QML_STORE=/path/to/tests/store-smoke kernora-store
```

The smoke test checks broad search results, categories, installed counts,
empty results and changing search queries. It logs `STORE_SMOKE_OK` on
success and does not install or remove apps. Also exercise installation,
launch, removal, cancellation and refresh in the graphical interface before
publishing a release.

What's New IDs are stable release identifiers. An optional `date` field
sets the displayed publication date independently; older entries continue
to derive their date from the ID. Keep the newest entry first.

## Launch regression

`tests/store-launch-smoke/run.sh` runs in a disposable desktop session with
Telegram installed as a Flatpak and Store closed. It puts conflicting native
launchers in a temporary data directory and records the command instead of
starting Telegram. The check requires the installed Flatpak scope and full
ref, so a Debian launcher or another Flatpak branch cannot silently win.
The test does not install or remove apps.

The Flatpak launch retains exported command options (including `--command`),
GPU preference and startup metadata. The installed desktop file is not rewritten.

## Installation completion test

In a disposable desktop VM with working Debian/Flathub sources, close
Store and run:

```sh
KERNORA_TEST_DISPOSABLE_SESSION=1 tests/store-install-smoke/run.sh
```

This test removes and reinstalls galculator and GNOME Calculator. It logs
transaction progress, installed source/version, event-loop heartbeats and
long timer gaps, and requires `STORE_INSTALL_OK` after both installations.
Normal authorization is still required. Do not run it in a personal session.
For full-VM freezes caused by exhausted host storage, see `VM_INSTALLATION.md`.

## Material 3 interface

The Store uses tonal navigation, responsive app headers, animated card state
layers and shape changes, and staggered entrances. Motion uses the desktop's
animation speed; the featured carousel pauses under the pointer and stops
advancing when animations are disabled. Category cards and carousel selectors
support keyboard activation.

To preview the QML with an installed Kernora Store backend, close Store first
and run in a Kernora desktop session:

```sh
KERNORA_QML_STORE=/absolute/path/to/packages/native/kernora-apps/apps/store/qml kernora-store
```

The owner-approved October 12 Material 3 changes shipped in
`kernora-apps 1.1.32` through the existing APT channel and the existing
`v1-ember-5` release. What's New describes the changes in English and Russian.
The release tag stays unchanged; the attached ISO still contains 1.1.30 and
installed systems receive the newer package through Settings > Updates.

The disposable QEMU preview passed navigation, search, details/back, installed
apps, updates, and 440-pixel window checks in dark and light themes. The catalogue smoke test reported
350 video results, 1121 games, and `STORE_SMOKE_OK`. Local screenshots,
UI state reports, and the animation recording are in
`_build/preview/store-material3/`; they are review artifacts, not release assets.

Delivery of 1.1.32 was verified against the public signed APT index and by
APT in QEMU (candidate 1.1.32, priority 900). The package and checksum
attached to the existing release were downloaded and matched the build.
The installed package passed the catalogue smoke test and English/Russian
release-note checks; the actual What's New window was inspected in QEMU.
Logs are in `out/test-logs/store/material3/`. The catalogue smoke test waits
for deferred search results within a 10-second bound and exits with a
nonzero status on failure.
