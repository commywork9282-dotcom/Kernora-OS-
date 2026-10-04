# Architecture

The distribution is an archive-first Debian derivative:

```text
signed Debian snapshot -> authenticated upstream source
                                      |
derived base-files -------------------+--> rootless package builds
native kernora-base ------------------+             |
                                                    v
                                      signed development APT archive
                                                    |
                                                    v
                                         reproducible minimal rootfs
                                                    |
                                         future installer / ISO
```

An ISO is a release artifact, not the source of the distribution. The source
of truth consists of package sources, patches, manifests, archive metadata and
the build pipeline in this repository.

## Implemented source fork

The first derived package is the complete Debian `base-files` source tree in
`packages/derived/base-files`, currently versioned
`13.8+deb13u6+kernora1`. It is built with Debian package tooling; it is not
extracted from, or layered onto, an installer ISO. The fork changes the Kernora
OS identity and vendor origin while retaining Debian parent and original
maintainer provenance.

The corresponding immutable upstream source is fetched from Debian snapshot
`20260901T000000Z`, authenticated, checksummed in `manifests/upstream.lock`, and
kept outside Git. `manifests/derived-packages.txt` records the mapping between
the Debian and Kernora versions.

Two more packages are Debian's own sources rebuilt with Kernora patches, which
`packages/derived/<name>` holds as a quilt series and a changelog entry:

* `calamares` (`3.3.14-1kernora1`): the installer's partition page in
  Material 3. `scripts/build-calamares-source` and
  `scripts/build-calamares-binary` build it.
* `polkit-kde-agent-1` (`4:6.3.6-1kernora1`): the authentication prompt as a
  Material 3 dialog. `scripts/build-derived-source` and
  `scripts/build-derived-binary` build it; they take any derived package by
  name and read its versions from `manifests/derived-packages.txt`.

Each is built offline in a build root with its Build-Depends
(`scripts/create-qt-build-rootfs`), indexed in the local archive, and pinned
in `configs/live/packages.txt`.

## Implemented native package

`packages/native/kernora-base` is a native Debian `3.0 (native)` metapackage,
version `1.0` and architecture `all`. It has an exact dependency on
`base-files (= 13.8+deb13u6+kernora1)`, making the Kernora identity package an
explicit part of the distribution base. Its source-to-binary path is exercised
by `make kernora-base-source` and `make kernora-base-binary`.

## Desktop package

`packages/native/kernora-desktop` (version `1.4`) carries the Kernora desktop:
the Material 3 design system, generated at build time from one seed colour,
the Kernora Plasma and icon themes, and the launcher and quick settings applets
of the panel. It is data and QML only (`Architecture: all`); its generators
need nothing but Python in the build chroot. See [DESKTOP.md](DESKTOP.md).

## Applications package

`packages/native/kernora-apps` (version `1.0`, `amd64`) carries Kernora's own
applications -- Settings, Files, Text Editor, Photos, Media Player,
Calculator, Screenshot and Welcome -- and `org.kernora.system`, the C++ Qt
Quick module they use to read and change the system. It is built with CMake
and KDE Frameworks in a separate Qt build root (`scripts/create-qt-build-rootfs`,
cached from the package's Build-Depends): `make kernora-apps-source` and
`make kernora-apps-binary`. See [APPS.md](APPS.md).

## Rootless package build

The implemented build path is:

```text
packages/derived/base-files
          |
          | make base-files-source
          v
_build/source-packages/{.dsc,.tar.xz}
          |
          | make base-files-binary
          |  + pinned mmdebstrap package
          |  + cached Debian trixie buildd rootfs
          v
_build/binary-packages/{.deb,.buildinfo,.changes}

packages/native/kernora-base
          |
          | make kernora-base-source / make kernora-base-binary
          v
_build/{source-packages,binary-packages}/kernora-base_1.0_*
```

`mmdebstrap` creates the `amd64` build environment from the same immutable
snapshot in `unshare` mode. The clean rootfs is cached at
`_cache/chroots/trixie-amd64-buildd.tar.xz`; later package builds copy and unpack
that cache into a temporary directory instead of modifying it. The actual
package compilation runs as mapped root inside new user, mount, PID and network
namespaces and does not require host root privileges. Temporary roots are
removed after the build.

Reproducibility inputs are declared rather than taken from the moving host:
Debian suite and snapshot timestamp, architecture, upstream source hashes, and
the `mmdebstrap` version and package hash are all pinned. Project-local APT
state and trust stores prevent the host `/etc/apt` configuration from becoming
an implicit build input.

The binary test inspects the resulting package, its relative `/etc/os-release`
link, Kernora identity, vendor ancestry, version, and the vendor-symlink
migration performed by `postinst`.

## Signed development archive

`make local-archive` assembles both source and binary packages under
`out/archive`, generates binary and source indexes, and signs both `Release`
and `InRelease`. An isolated APT client verifies the signatures, index hashes,
versions, package dependency and package selection.

The signing identity is intentionally a local development key. It is generated
under ignored `_state` directories, has a one-year expiry and an
`archive@kernora.invalid` UID, and is exported into the archive so the local
proof can be consumed. It is not the Kernora production release key and must
not be promoted as one.

## Minimal rootfs

`make minimal-rootfs` uses `mmdebstrap --variant=minbase` in rootless `unshare`
mode. The explicit package manifest installs `kernora-base=1.1`, whose exact
dependency selects the Kernora `base-files` fork. The resulting filesystem is
tested inside a rootless chroot for OS identity, dpkg vendor, package versions,
APT trust scoping and access to the embedded development archive.

The rootfs contains:

- the development archive at `/usr/share/kernora/archive`;
- its public key at
  `/usr/share/keyrings/kernora-development-archive-keyring.gpg`;
- a key-scoped `file:` APT source for that archive;
- timestamp-pinned Debian `trixie`, `trixie-updates` and `trixie-security`
  snapshot sources.

The release artifact is
`out/rootfs/kernora-1-ember-amd64.tar.xz`, with a sibling `.sha256` file. Tar
members are sorted and normalized to the snapshot epoch, numeric root
ownership, and stable PAX metadata. With the same pinned inputs, including the
same development signing key, repeated builds produce the same artifact hash.

## Stage boundaries

1. **Stage 0:** authenticate/pin upstream sources and validate the repository
   (implemented).
2. **Stage 1:** choose identity; build the forked `base-files` and native
   `kernora-base`; publish and verify a signed local development archive
   (development proof implemented). Production key governance, public URLs and
   real maintainer/archive email addresses remain release blockers.
3. **Stage 2:** build, test and checksum a reproducible minimal rootfs from the
   declared development archive and Debian snapshot sources (development proof
   implemented).
4. **Stage 3:** add kernel/policy/desktop choices and build an installer image.
   An installer and bootable ISO are not implemented yet.
5. **Stage 4:** reproducibility, upgrade, security and release testing.
