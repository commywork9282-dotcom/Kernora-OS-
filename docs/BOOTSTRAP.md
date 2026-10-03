# Bootstrap

Stage 0 does not modify `/etc/apt` and does not require root. It downloads the
three Debian 13 public archive keys from `ftp-master.debian.org`, checks their
full fingerprints, and uses a project-local APT state directory. It then
downloads the pinned `debian-keyring` package through that authenticated APT
index so signatures made by individual Debian source maintainers can also be
verified without installing a keyring into the host OS.

The upstream suite is never addressed as mutable `stable`. Both suite and
snapshot timestamp are declared in `configs/upstream/base.env`.

The current values are Debian `trixie`, `amd64`, and snapshot
`20260901T000000Z` (`2026-09-01T00:00:00Z`). Upstream source file hashes are
recorded in `manifests/upstream.lock`. The locally extracted `mmdebstrap`
package is separately pinned by version and SHA-256 in the same configuration
file.

Required host commands:

- `bash`, `curl`, `gpg`;
- `apt-get`, `dpkg-source`, `sha256sum`.

Fetching and inspecting source packages does not require the package-build
environment. Start or refresh the authenticated source inputs with:

```sh
make sources
make verify
```

## Source package

`packages/derived/base-files` is an in-repository fork of the full Debian source
package, not an ISO customization overlay. Build it with:

```sh
make base-files-source
```

The target validates both the repository and the Kernora identity before
running `dpkg-source`. It produces:

```text
_build/source-packages/base-files_13.8+deb13u6+kernora1.dsc
_build/source-packages/base-files_13.8+deb13u6+kernora1.tar.xz
```

## Native base metapackage

`packages/native/kernora-base` is the distribution's own `3.0 (native)` source
package. Version `1.0` is an architecture-independent metapackage with an exact
dependency on `base-files (= 13.8+deb13u6+kernora1)`.

Build its source and binary packages separately with:

```sh
make kernora-base-source
make kernora-base-binary
```

The resulting files are written alongside the derived package artifacts:

```text
_build/source-packages/kernora-base_1.0.dsc
_build/source-packages/kernora-base_1.0.tar.xz
_build/binary-packages/kernora-base_1.0_all.deb
_build/binary-packages/kernora-base_1.0_amd64.buildinfo
_build/binary-packages/kernora-base_1.0_amd64.changes
```

## Rootless binary package

Binary builds require Linux unprivileged user namespaces, subordinate UID/GID
mappings, and host utilities including `unshare`, `newuidmap`, `newgidmap`,
`chroot`, `tar`, and Debian package tools. No system package is installed and no
host APT configuration is rewritten: the pinned `mmdebstrap` `.deb` is fetched
through the project-local authenticated APT setup and extracted under
`_state/tools/mmdebstrap`.

The complete build is:

```sh
make base-files-binary
```

This target performs the following operations:

1. validates the layout, upstream hashes and derived identity;
2. builds the source package;
3. bootstraps pinned `mmdebstrap` version `1.5.7-1+deb13u1`;
4. creates or reuses a clean Debian `trixie` `buildd` rootfs from snapshot
   `20260901T000000Z`;
5. builds the binary in rootless namespaces with
   `dpkg-buildpackage --build=binary --no-sign`;
6. tests the metadata and installed Kernora identity in the resulting package.

The clean environment is cached at:

```text
_cache/chroots/trixie-amd64-buildd.tar.xz
```

The cache is treated as read-only during package builds: every build uses a
temporary extracted copy. The binary results are:

```text
_build/binary-packages/base-files_13.8+deb13u6+kernora1_amd64.deb
_build/binary-packages/base-files_13.8+deb13u6+kernora1_amd64.buildinfo
_build/binary-packages/base-files_13.8+deb13u6+kernora1_amd64.changes
```

For debugging or warming the cache independently, the lower-level Make targets
are also available:

```sh
make build-tools
make build-rootfs
```

## Signed local development archive

Build both packages and publish them into a local APT archive with:

```sh
make local-archive
```

The target creates or reuses an Ed25519 development signing key, builds both
source and binary packages, generates `Packages`, `Sources`, `Release`,
`Release.gpg` and `InRelease`, and installs the completed archive at
`out/archive/`. The archive test verifies signatures and Release hashes, then
uses an isolated project-local APT state to confirm that APT selects the exact
Kernora versions and dependency.

The development key is local build state under `_state/gnupg` and `_state/keys`.
It expires after one year, uses `archive@kernora.invalid`, and is explicitly not
a production release key. The public key is copied into the development archive
as `kernora-development-archive-keyring.gpg`; the private key is never copied to
`out/`.

## Reproducible minimal rootfs

Build the complete minimal filesystem with:

```sh
make minimal-rootfs
```

This target depends on `make local-archive`, then runs rootless `mmdebstrap` in
`minbase` mode. `configs/rootfs/minimal-packages.txt` currently requests the
versioned package `kernora-base=1.0`; its dependency pulls in the exact Kernora
`base-files` build.

Before packaging, a rootless chroot test checks the Kernora OS identity, dpkg
vendor, installed package versions, APT key scoping and readability of the
embedded signed archive. The output is:

```text
out/rootfs/kernora-1-ember-amd64.tar.xz
out/rootfs/kernora-1-ember-amd64.tar.xz.sha256
```

Verify it with:

```sh
(cd out/rootfs && sha256sum -c kernora-1-ember-amd64.tar.xz.sha256)
```

The tar stream uses sorted paths, the snapshot timestamp as `SOURCE_DATE_EPOCH`,
numeric root ownership and normalized PAX timestamps. Repeating the build with
the same declared inputs and the same development signing key therefore yields
the same rootfs checksum.

The installed `/etc/apt/sources.list` contains four declared sources:

1. the embedded development archive at `/usr/share/kernora/archive`, scoped to
   its embedded public key;
2. Debian `trixie` from snapshot `20260901T000000Z`;
3. `trixie-updates` from the same snapshot;
4. `trixie-security` from the matching Debian security snapshot.

Keeping the development archive inside the rootfs makes its packages and signed
metadata inspectable without a public Kernora server, while the Debian sources
remain immutable timestamped upstream references.

All files below `_build`, `_cache`, `_state`, and `out` are generated state and
are ignored by Git. Repeating the workflow uses the same declared snapshot,
versions and hashes instead of mutable `stable` repositories or host-installed
build tools.

Stage 1 and Stage 2 now form a complete local development proof, not a public
release. Production publication remains blocked until real project URLs and
email addresses replace the empty/`.invalid` development values and a separate
production archive key is created under an approved key ceremony. Installer
integration and a bootable ISO are also still unimplemented.
