# Updates

An installed Kernora system updates from four APT archives, five with demo
updates on. The `kernora-archive` package sets them up, and `kernora-base`
depends on it, so every installation has it.

| Archive | What comes from it | How it is installed |
| --- | --- | --- |
| Debian security, `security.debian.org`, `trixie-security` | security fixes, kernel updates among them | automatically, once a day |
| LibreWolf, `repo.librewolf.net` | the browser | automatically, once a day |
| Debian, `deb.debian.org`, `trixie` and `trixie-updates` | Debian point releases | in Settings > Updates |
| Kernora, `commywork9282-dotcom.github.io/kernora-updates` | Kernora's own packages | in Settings > Updates |
| Kernora demo, same site, `ember-demo` | new Kernora packages before everyone else, only with Demo updates on | in Settings > Updates, after turning it on in Settings > System |

The ISO is still built from the pinned Debian snapshot (`configs/upstream/base.env`).
Only the installed system points at the live archives: `build-live-rootfs` removes
the build's `sources.list` and its copy of the Kernora archive.

Both the Debian archive and its security updates come with the `main` and
`non-free-firmware` components. The image ships the firmware that graphics
cards, Wi-Fi, Bluetooth and laptop sound need, and CPU microcode
(`configs/live/packages.txt`: AMD, Intel and NVIDIA graphics, Intel, Realtek,
Qualcomm, MediaTek and Broadcom Wi-Fi, SOF sound); without it AMD's integrated
graphics stop with "Fatal error during GPU init" and most Wi-Fi stays dark.

The installer copies the system on the medium, which may be days of updates
behind. When the computer is online it brings the new system up to date before
it finishes (`shellprocess@upgrade` in `data/calamares/settings.conf`:
`apt-get update`, `full-upgrade` and `update-grub` in the target). Offline,
the step is skipped and Settings > Updates catches up later.

## Automatic updates

`unattended-upgrades` runs from APT's daily timers. `kernora-archive` enables it
in `/etc/apt/apt.conf.d/21kernora-auto-upgrades` and chooses what it installs in
`51kernora-unattended-upgrades`. Debian's own defaults match archives by the
distribution's codename. On Kernora that codename is `ember`, so they would match
nothing; the Kernora file names `trixie-security` instead.

A kernel update takes effect after a restart. The live session never updates
itself: the timers carry `ConditionKernelCommandLine=!boot=live`.

Settings > Updates shows everything else through PackageKit and installs it on
request.

## Notifications

`kernora-update-notifier` (kernora-apps) starts with the session from
`/etc/xdg/autostart/org.kernora.update-notifier.desktop`. Two minutes after
login, and then every six hours, it asks PackageKit for updates. It refreshes
the package lists itself only when APT's daily refresh is more than a day old
and the connection is not metered. When the list holds a package it has not
announced yet, a notification from Settings says how many updates are ready,
and whether security fixes are among them; "View" opens Settings > Updates.
When `/run/reboot-required` appears (the kernel hook of `unattended-upgrades`
creates it), it asks once per boot for a restart, with a "Restart" button that
opens the session's restart prompt.

The events are in `kernora-updates.notifyrc`, so the notification server draws
them like any other Kernora notification. What has been announced is kept in
`~/.local/state/kernora-update-notifierstaterc`. In the live session the
notifier only keeps the app icons in shape (docs/DESKTOP.md, Other apps'
icons) and checks no updates.

## Demo updates

Settings > System has a Demo updates switch under Early access, off by
default. Turning it on runs `/usr/libexec/kernora-update-channel set demo`
through pkexec (polkit action `org.kernora.update-channel`, admin password).
That copies
`/usr/share/kernora/apt/kernora-demo.sources` to
`/etc/apt/sources.list.d/kernora-demo.sources`, which adds the `ember-demo`
suite from the same site and key, and Settings checks for updates again.

Both suites come from the same site, so the 900 pin below covers both and APT
just takes the higher version. `ember-demo` only holds packages newer than the
normal ones, so a demo system gets those from it and everything else from
`ember`.

Turning it off removes the file. Demo versions that are already installed
stay, APT doesn't downgrade. As soon as the normal updates have the same or a
higher version the system is back in line with everyone else. When the
switch is on, `kernora-archive` refreshes the file on upgrade, and it removes
it on purge.

## What's new

After an update, the next login opens a "What's new" window: Welcome started
as `kernora-welcome --whats-new`. It says what changed, in plain words, from
the release notes in `/usr/share/kernora/whatsnew.json`
(`packages/native/kernora-apps/data/whatsnew.json`). Each release there has an
`id` (its date, newest first; a second release on the same day gets a suffix
such as `2026-10-08-2`) and items with an icon, a title and a text, each in
English and Russian. Releases of the same day are shown as one.

The notifier opens the window when the newest `id` differs from `Seen` in
`kernora-welcomerc` `[WhatsNew]`, six seconds after login. On a new
installation, where Welcome itself is still due, it only records the newest
release as seen. The window shows every release since the one seen last (up
to three when none was seen yet) and then records the newest.

## Kernora's packages win over Debian's

`/etc/apt/preferences.d/kernora-archive.pref` gives the Kernora archive priority
900. Debian therefore never replaces Kernora's builds of `base-files`, Calamares
or `polkit-kde-agent-1`, even when it releases a newer version of the same
package. Such a version has to be rebuilt into the Kernora archive to reach
users.

## Publishing an update

1. Change the package and add a changelog entry with a higher version.
2. If people will notice the change, add a release at the top of
   `packages/native/kernora-apps/data/whatsnew.json` and publish kernora-apps
   with it, so that the "What's new" window tells them about it.
3. If the ISO should carry the new version, update the pins in
   `configs/live/packages.txt` and the version checks in `tests/`.
4. Run `make publish`. It builds every package and the local archive, runs
   `tests/test-publish-updates.sh`, then signs the archive with the Kernora
   archive key and force-pushes it to the `kernora-updates` repository, which
   GitHub Pages serves a minute later. The demo suite there is kept, only the
   demo packages the new normal ones caught up with are dropped.

Systems pick it up at their next check: the daily refresh, or Check in
Settings > Updates.

`kernora-updates` holds only the current packages, normal and demo. Each
publication replaces all of its contents in a single commit, so the
repository does not grow.

### Demo first

`make publish-demo` builds the same way but leaves the normal updates exactly
as they are published. Into `ember-demo` it puts every package from
`out/archive` whose version is newer than the published normal one, replacing
what the demo had before, and it refuses when nothing is newer.

Give the packages the version the release will have. When the demo is good,
`make publish` the same tree: the packages are identical, systems on the demo
already have them and nothing reinstalls. If a package changes after it went
to the demo, raise its version again. Both commands refuse to publish a
package under a version the demo already has with other contents, because
systems that installed the demo would never get the change. They also warn
when a package changed but kept the version it is published with.

## The signing key

The Kernora OS Archive Signing Key is an ed25519 key with fingerprint
`76EE FBDB 0D37 0DF1 0617 45C3 8AD5 1AE6 FA0E F01C`, created 2026-10-03. It
expires on 2029-10-02.

- The private key lives in `_state/gnupg/archive` on the build machine and is
  never committed. `scripts/create-archive-key` made one backup when it created
  the key, `~/kernora-archive-key-secret.asc`. Keep that backup offline. Without
  it no update can be published, and a replacement key could only reach
  installed systems by hand.
- The public key is
  `packages/native/kernora-archive/keyrings/kernora-archive-keyring.asc`. It is
  installed as `/usr/share/keyrings/kernora-archive-keyring.asc` and also served
  next to the archive.
- Before the key expires, extend it with `gpg --homedir _state/gnupg/archive
  --quick-set-expire <fingerprint> 3y`. Then run `scripts/create-archive-key`,
  which exports the public key again, and publish a new `kernora-archive` while
  the old expiry date still holds.

## Systems installed before this

The first test ISO (`v1-ember`, 2026-10-03) came before this change: its
systems still point at the build snapshot and take no updates. To get updates
there, install `kernora-archive` from the archive once, by hand:

```sh
wget https://commywork9282-dotcom.github.io/kernora-updates/pool/main/k/kernora-archive/kernora-archive_1.0_all.deb
sudo apt install ./kernora-archive_1.0_all.deb
sudo rm /etc/apt/sources.list
```
