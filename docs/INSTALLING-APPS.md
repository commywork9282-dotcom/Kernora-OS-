# Installing applications

Kernora Store combines Debian's AppStream catalogue with Flathub. APT searches only the configured APT repositories, and package names can differ from the names displayed in the Store. Installing a Flatpak does not add its application to Debian's repositories.

Archive package `kernora-archive 1.3` enables Debian `main`, `contrib`, `non-free` and `non-free-firmware`. It also enables `i386` for new amd64 installations and upgrades from older archive packages. No applications are installed merely by enabling these sources. Later archive upgrades preserve an administrator's decision to remove `i386`.

## Steam

After installing the Kernora update, refresh the package lists and use Debian's package name:

```sh
sudo apt update
sudo apt install steam-installer
```

The `steam-installer` package is in Debian `contrib` and requires 32-bit dependencies. The command `apt install Steam` is not equivalent: APT package names are case-sensitive. The Store also offers Steam from Flathub, which supplies its own runtime.

For graphics-specific 32-bit libraries, follow the [Debian Steam guide](https://wiki.debian.org/Steam). Enabling `i386` makes those packages available; it does not install every graphics driver.

## Proton VPN

Proton VPN comes from Proton's own APT repository. Enabling additional Debian components does not add it. Follow the [official Debian and Ubuntu installation instructions](https://protonvpn.com/support/linux-vpn-debian-ubuntu/), which currently use the package `proton-vpn-gnome-desktop` after connecting the official repository.

The following release package and checksum were checked on 5 November 2026:

```sh
curl --fail --location --output protonvpn-stable-release_1.0.10_all.deb https://repo.protonvpn.com/debian/dists/stable/main/binary-all/protonvpn-stable-release_1.0.10_all.deb
printf '%s\n' 'c8a9fffb4ebdd63db08ce7f11c9b0ac394064ae6a210feb9ab63a0f7d8d060a7  protonvpn-stable-release_1.0.10_all.deb' | sha256sum --check
sudo apt install ./protonvpn-stable-release_1.0.10_all.deb
sudo apt update
sudo apt install proton-vpn-gnome-desktop
```

Stop if downloading or verifying the checksum fails. Check the official instructions for a newer release rather than skipping verification. Installing the release package explicitly adds Proton's repository and signing key; Kernora does not add that third-party source by default.

Proton officially supports its Linux app on GNOME. Kernora uses Plasma. Resolving the package dependencies on Debian is distinct from testing VPN login, key storage, connectivity and the kill switch in a Kernora session.

## If APT still cannot find a package

Run `sudo apt update` and read any repository errors first, then search with `apt search <name>`. A package may have a different name, be available only through Flathub or the developer's repository, or not support the computer's architecture. A failed update can leave old package lists in place.
