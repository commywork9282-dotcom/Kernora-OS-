SHELL := /bin/bash

.PHONY: check keyring index signer-keyring sources unpack verify \
	build-tools build-rootfs base-files-source base-files-binary \
	kernora-base-source kernora-base-binary kernora-archive-source \
	kernora-archive-binary kernora-desktop-source \
	kernora-desktop-binary kernora-apps-source kernora-apps-binary \
	kernora-quickshare-source kernora-quickshare-binary quickshare-crates \
	calamares-source calamares-binary \
	polkit-kde-agent-1-source polkit-kde-agent-1-binary \
	development-archive-key archive-key local-archive publish publish-demo \
	minimal-rootfs iso-tools librewolf live-rootfs iso iso-smoke

check:
	./scripts/check-host

keyring: check
	./scripts/bootstrap-debian-keyring

index: keyring
	./scripts/update-upstream-index

signer-keyring: index
	./scripts/bootstrap-debian-signer-keyring

sources: signer-keyring
	./scripts/fetch-sources
	./scripts/unpack-sources

unpack:
	./scripts/unpack-sources

verify:
	./tests/lint-layout.sh
	./tests/test-squashfs-root.sh
	./tests/test-base-files-identity.sh
	./tests/test-kernora-base-source.sh
	./tests/test-kernora-archive-source.sh
	./tests/test-kernora-desktop-source.sh
	./tests/test-kernora-quickshare-source.sh
	./scripts/verify-sources

base-files-source: verify
	./scripts/build-base-files-source

build-tools: signer-keyring
	./scripts/bootstrap-build-tools

build-rootfs: build-tools
	./scripts/create-build-rootfs

base-files-binary: verify build-rootfs
	./scripts/build-base-files-binary

kernora-base-source: verify
	./scripts/build-kernora-base-source

kernora-base-binary: verify build-rootfs
	./scripts/build-kernora-base-binary

kernora-archive-source: verify
	./scripts/build-kernora-archive-source

kernora-archive-binary: verify build-rootfs
	./scripts/build-kernora-archive-binary

kernora-desktop-source: verify
	./scripts/build-kernora-desktop-source

kernora-desktop-binary: verify build-rootfs
	./scripts/build-kernora-desktop-binary

kernora-apps-source: verify
	./scripts/build-kernora-apps-source

kernora-apps-binary: verify build-rootfs
	./scripts/build-kernora-apps-binary

quickshare-crates:
	./scripts/fetch-quickshare-crates

kernora-quickshare-source: verify
	./scripts/build-kernora-quickshare-source

kernora-quickshare-binary: verify build-rootfs
	./scripts/build-kernora-quickshare-binary

calamares-source: verify
	./scripts/build-calamares-source

calamares-binary: verify build-rootfs
	./scripts/build-calamares-binary

polkit-kde-agent-1-source: verify
	./scripts/build-derived-source polkit-kde-agent-1

polkit-kde-agent-1-binary: verify build-rootfs
	./scripts/build-derived-binary polkit-kde-agent-1

development-archive-key:
	./scripts/create-development-archive-key

local-archive: base-files-binary kernora-base-binary kernora-archive-binary kernora-desktop-binary \
		kernora-apps-binary kernora-quickshare-binary calamares-binary polkit-kde-agent-1-binary \
		development-archive-key
	./scripts/build-local-archive

minimal-rootfs: local-archive
	./scripts/build-minimal-rootfs

iso-tools: signer-keyring
	./scripts/bootstrap-iso-tools

librewolf:
	./scripts/fetch-librewolf

archive-key:
	./scripts/create-archive-key

publish: local-archive
	./tests/test-publish-updates.sh
	./scripts/publish-updates

publish-demo: local-archive
	./tests/test-publish-updates.sh
	./scripts/publish-updates --demo

live-rootfs: local-archive librewolf
	./scripts/build-live-rootfs

iso: live-rootfs iso-tools
	./scripts/build-iso

iso-smoke: iso
	./scripts/smoke-test-iso
