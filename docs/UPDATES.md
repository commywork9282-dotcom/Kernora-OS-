# Updates

An installed Kernora system updates from four APT archives. The
`kernora-archive` package sets them up, and `kernora-base` depends on it, so
every installation has it.

| Archive | What comes from it | How it is installed |
| --- | --- | --- |
| Debian security, `security.debian.org`, `trixie-security` | security fixes, kernel updates among them | automatically, once a day |
| LibreWolf, `repo.librewolf.net` | the browser | automatically, once a day |
| Debian, `deb.debian.org`, `trixie` and `trixie-updates` | Debian point releases | in Settings > Updates |
| Kernora, `commywork9282-dotcom.github.io/kernora-updates` | Kernora's own packages | in Settings > Updates |

The ISO is still built from the pinned Debian snapshot (`configs/upstream/base.env`).
Only the installed system points at the live archives: `build-live-rootfs` removes
the build's `sources.list` and its copy of the Kernora archive.

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
`~/.local/state/kernora-update-notifierstaterc`. The notifier exits at once in
the live session.

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
4. Run `make publish`. It builds every package and the local archive. It then
   signs the archive with the Kernora archive key and force-pushes it to the
   `kernora-updates` repository, which GitHub Pages serves a minute later.

Systems pick it up at their next check: the daily refresh, or Check in
Settings > Updates.

`kernora-updates` holds only the current packages. Each publication replaces
all of its contents in a single commit, so the repository does not grow.

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
