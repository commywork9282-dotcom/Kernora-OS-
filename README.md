# Kernora OS

Kernora OS is a desktop Linux distribution based on Debian 13 (trixie). It
runs KDE Plasma 6 with its own shell, apps and themes, designed after
Material 3.

This repository has everything needed to build the live ISO: Kernora's own
packages, the changes made to a few Debian packages, the image configuration,
and the build scripts and tests.

The project is in early development. Test builds are published under
Releases. Packages are signed with a development key for now; there is no
release key yet.

## What's in the image

- Debian 13.6 from a fixed snapshot (2026-09-01), Linux 6.12, KDE Plasma 6.3.
- A Kernora shell on top of Plasma: panel, app launcher, quick settings,
  notifications, lock screen, Alt+Tab and power menu. All colours come from
  one seed colour, `#ff6a1e`. Settings can switch the look between Material
  Design 1, 2 and 3.
- Kernora apps in place of KDE's: Settings, Files, Text Editor, Photos, Media
  Player, Calculator, Screenshot, Terminal (Alacritty) and Welcome, plus a
  file chooser that every program uses.
- Live wallpapers: Kernora Shapes, Tower, Rhythm and Marble Run.
- LibreWolf as the browser. It isn't in Debian, so the build installs one
  pinned version from the LibreWolf repository, and the installed system
  gets updates from there.
- Calamares as the installer, restyled to match.
- English and Russian. The live session language is chosen in the boot menu.

KDE's standalone apps (Dolphin, Konsole, Kate, Discover, Spectacle and others)
are left out; the list is in `configs/live/excluded-packages.txt`.

## Building

You need a Debian-based machine with:

- unprivileged user namespaces and subuid/subgid mappings (everything builds
  without root);
- `apt-get`, `dpkg-dev`, `curl`, `gpg` and `gpgv`;
- `grub-common`, `grub-pc-bin`, `grub-efi-amd64-bin`, `xorriso`,
  `squashfs-tools` and `xz-utils` for the ISO;
- `qemu-system-x86` for the boot tests;
- about 10 GB of free disk space.

The host's own APT setup is not touched. Keyrings, tools and caches live in
the working tree.

Build the ISO and check that it boots in QEMU (BIOS and UEFI):

```sh
make iso-smoke
```

The result is `out/iso/kernora-1-ember-live-amd64.iso` with a `.sha256`
file next to it. `make iso` builds the ISO without the boot tests.

Steps can also be run one at a time, for example `make local-archive` (all
packages and the signed APT archive) or `make live-rootfs`. See the
`Makefile` for the full list.

Builds are reproducible: the Debian snapshot, tool versions and every
downloaded file are pinned by SHA-256, and archives are written with fixed
file order, times and owners. Build outputs (`_build/`, `_cache/`, `out/`,
`_state/`) stay out of Git.

To try changes to the shell or the apps without rebuilding the ISO,
`scripts/preview-desktop` boots the desktop in QEMU and syncs files into it.

## Layout

- `packages/native/`: Kernora's own packages (`kernora-base`,
  `kernora-desktop`, `kernora-apps`).
- `packages/derived/`: changes to Debian's `base-files`, Calamares and
  `polkit-kde-agent-1`.
- `configs/`: the upstream pins, the live image and the system identity.
- `scripts/`: build steps. `tests/`: checks for every package and image.
- `docs/`: how it all works. Start with
  [docs/ARCHITECTURE.md](docs/ARCHITECTURE.md), then
  [docs/DESKTOP.md](docs/DESKTOP.md) for the shell and design system and
  [docs/APPS.md](docs/APPS.md) for the apps.

## License

Kernora OS is released under the GNU GPL version 3 (`LICENSE`). Kernora's own
files are GPL-2.0-or-later. `NOTICE` lists the parts that come from others
and their licenses.
