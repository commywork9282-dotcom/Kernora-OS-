# APT availability regression

Build `kernora-archive`, then supply the previously published archive 1.2 package:

```sh
./scripts/build-kernora-archive-binary
./tests/apt-availability/run.sh /path/to/kernora-archive_1.2_all.deb
```

The test requires network access, curl, unshare/user namespaces, mount, chroot, tar, dpkg and the cached `trixie-amd64-buildd.tar.xz`. It creates and removes a separate root filesystem. It never changes the host's sources or architectures.

It installs archive 1.2 and confirms that Steam cannot be located, enables the demo source, then upgrades to archive 1.3. It checks the real dpkg migration, signed repository refresh without unsupported-i386 warnings, and an actual install of `steam-installer` and its i386 dependencies. It does not launch Steam or download Valve's client.

In the same disposable system it checks the checksum of Proton's official repository package, explicitly installs that package, verifies the signed package lists, and resolves the documented Proton VPN package without removals. It does not start a VPN connection or test the GUI. Proton's repository is not part of Kernora's default configuration.
