# VM freezes while Store installs an app

On 12 October 2026, the reported full-VM freeze at about 99% was traced to
host storage exhaustion. The host had approximately 426 MB available;
libvirt logged `Transitioned guest vm1 to paused state due to IO error`,
including at 16:18. Host services also logged `No space left on device`.
The guest itself still had 9.1 GB available, so checking only the guest's
free space did not reveal the problem.

The VM disk was copied while the original VM was shut down. `qemu-img
check` found no image-structure errors. A disposable overlay on an HDD
with ample free space booted the installed OS. The original Store package
1.1.30 was retained; no installer code was replaced for this comparison.
Temporary autologin and test authorization were applied only to the overlay.

Through Store, galculator 2.1.4-2 installed from Debian and GNOME Calculator
51.1 installed from Flathub, including approximately 790 MB of downloads.
The Flatpak transaction reached 99% and completed. The QML event-loop
heartbeat continued through that stage. These tests distinguish this host
I/O pause from an application-specific download failure.

On this host, build caches and temporary build outputs were moved to the
HDD with links preserving their paths. Windows 10 and Xubuntu installer
ISOs were also moved from Downloads to `/mnt/hdd2tb/ISO-archives`, with
SHA256 verified before replacing their old paths with links. Available
SSD space increased to approximately 13 GB. The original VM disk and its
libvirt configuration were not changed.

For another occurrence, inspect both host and guest free space and the
hypervisor's state/error report. A VM paused for a host I/O error needs the
host storage problem resolved before resuming it. Updating the guest's
Store package does not free space on the host.

The local diagnostic logs and relocation manifest are under
`out/test-logs/store/`. The repeatable installation fixture is
`tests/store-install-smoke/`; use it only in a disposable desktop session.

A second install/remove/install pass also completed. During that pass,
21 QMP status checks all reported `running`; no I/O pause occurred.
The longest recorded QML timer gap was 2.129 seconds while loading the
catalogue. No timer gap above 1.5 seconds was logged during the transactions.
Shared Flatpak runtimes were already present for the repeat pass.
