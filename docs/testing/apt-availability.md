# APT application availability

The community reported missing Steam and Proton VPN packages. The shipped Debian configuration enabled `main` and `non-free-firmware` only. Debian's `steam-installer` is in `contrib` and requires i386 dependencies on amd64. Proton VPN is distributed through the vendor's own repository.

Archive package 1.3 enables Debian's application components and adds i386 during new amd64 installs and upgrades from before 1.3. It scopes Kernora's own repositories to amd64. Existing custom conffiles retain dpkg's normal handling. Later upgrades do not re-add i386 after an administrator deliberately removes it. No Proton repository is added by default.

Validation completed in a disposable Debian root filesystem with real APT and dpkg:

- The previously published archive 1.2 package was installed and APT could not install `steam-installer`.
- The demo source was enabled before upgrading to archive 1.3. The actual upgrade enabled i386 and refreshed the demo source's architecture restriction.
- Signed Debian and Kernora package lists refreshed without unsupported-i386 warnings.
- APT installed `steam-installer`, `steam-libs-i386` and their dependencies without removing packages.
- The official Proton repository package matched the checksum in Proton's instructions. Its signed package lists supplied Proton VPN, and the documented `proton-vpn-gnome-desktop` installation plan resolved without removals.

Eight focused maintainer-script tests additionally cover fresh installs, old-version upgrades, existing foreign architectures, later administrator opt-outs, non-amd64 systems, aborts and dpkg failures. Source and binary-package checks validate the shipped configuration and maintainer scripts in both channels.

The test does not launch Steam, download Valve's client, or establish a VPN connection. Proton's official GUI support targets GNOME; Kernora uses Plasma. See [Installing applications](../INSTALLING-APPS.md) for user-facing installation steps and upstream references.
