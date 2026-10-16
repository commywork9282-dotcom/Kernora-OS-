# Store

The Store finds apps in Debian's AppStream catalogue and in Flatpak remotes.
Flathub comes preconfigured through a packaged remote file, remotes and apps
you already have are left alone. If an app exists in both, the app page lets
you pick the source before installing. Apps you already have get removed and
updated from wherever they were installed from.

Flatpak stuff runs off the UI thread, with progress and a cancel button.
Closing the window during an install just hides it until it's done. Debian
packages go through PackageKit and the normal password prompt. Local `.deb`
and `.flatpakref` files open in the Store, and `appstream:` links open an
app page. Nothing gets installed just from opening a file or a page.

The Installed page also lists apps you installed some other way, as long as
there's metadata for them. Flatpak apps and runtimes update in the Store,
Debian and Kernora updates stay in Settings. If checking for updates fails,
the Store keeps the last list and shows a retry button instead of pretending
everything is fine.

Descriptions and screenshots come from the repos. Star ratings come from
ODRS, get cached for three days and just don't show if ODRS is down. Artwork
is cached on disk. Offline, the cached catalogue and your installed apps
still work, downloading new stuff obviously needs a connection.

## Look

Kinda like Google Play on purpose: a top bar with **Apps**, **Games** and
**Categories** tabs, search and a **My apps** button (it shows a badge when
updates are waiting). No big featured carousel or "popular" banner, the Apps
tab is just rows of apps per category, each row title opens the full
category. Games is a short recommended row (from `data/store/featured.json`)
and then every game in a list.

App tiles are the icon on a rounded plate, the name and the rating. App
pages have the icon and developer up top, a stats row (rating, source,
version, size), a big Install button (or Uninstall + Open/Update once it's
installed), screenshots, "About this app", ratings with a per-star breakdown
from ODRS, and app info at the bottom. Updates and installed apps live in
My apps.

Animations follow the desktop animation speed and there's not a lot of
them: tabs slide their underline, pages fade in, rows scroll smoothly.

To preview QML changes against an installed Store backend, close the Store
and run this in a Kernora session:

```sh
KERNORA_QML_STORE=/absolute/path/to/packages/native/kernora-apps/apps/store/qml kernora-store
```

## Testing

`scripts/build-kernora-apps-binary` and `scripts/build-kernora-desktop-binary`
build the packages and check the Store module, launcher, dependencies, remote
file and the Russian translation.

Catalogue smoke test, in a throwaway Kernora session with both catalogues
downloaded:

```sh
KERNORA_QML_STORE=/path/to/tests/store-smoke kernora-store
```

It checks search results, categories, installed counts, empty results and
changing the search. It prints `STORE_SMOKE_OK` when it's happy, waits up to
10 seconds for search results and exits with an error otherwise. It doesn't
install or remove anything, so also click through installing, launching,
removing, cancelling and refreshing by hand before a release.

### Launching

`tests/store-launch-smoke/run.sh` runs in a throwaway session with Telegram
installed as a Flatpak and the Store closed. It adds conflicting native
launchers in a temp folder and records the command instead of actually
starting Telegram. It makes sure the installed Flatpak scope and full ref
are used, so a Debian launcher or another Flatpak branch can't win by
accident. Launching keeps the exported command options (`--command` too),
GPU preference and startup info. The installed desktop file isn't changed.

### Installing

In a throwaway VM with working Debian and Flathub sources, close the Store
and run:

```sh
KERNORA_TEST_DISPOSABLE_SESSION=1 tests/store-install-smoke/run.sh
```

It removes and reinstalls galculator and GNOME Calculator, logs progress,
installed source and version, and checks the UI stays responsive. It needs
`STORE_INSTALL_OK` after both installs. You still have to type your password.
Don't run it in your normal session. If the whole VM freezes, check
[VM_INSTALLATION.md](VM_INSTALLATION.md) first, it was the host's disk last
time.

## What's New ids

What's New ids are stable release ids. An optional `date` field sets the date
that's shown, older entries just take it from the id. Newest entry goes
first.
