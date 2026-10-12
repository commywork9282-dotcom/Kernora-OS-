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
