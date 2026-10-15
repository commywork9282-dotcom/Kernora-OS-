# VM freezes while the Store installs an app

Someone reported the whole VM freezing at around 99% while the Store was
installing an app (Oct 12). Turned out it wasn't the Store at all: the
**host** had run out of disk space. It had like 426 MB left, libvirt logged
`Transitioned guest vm1 to paused state due to IO error` (once at 16:18 too)
and host services were throwing `No space left on device`. The guest itself
still had 9.1 GB free, so looking at free space inside the VM didn't show
anything.

To double check, I copied the VM disk while it was shut down (`qemu-img
check` found no errors) and booted a throwaway overlay of it on a drive with
plenty of space. Same Store version (1.1.30), nothing changed in the
installer.

From the Store, galculator 2.1.4-2 installed from Debian and GNOME
Calculator 51.1 from Flathub, around 790 MB of downloads. The Flatpak install
went through 99% and finished, and the UI kept responding the whole time. A
second remove/install round also worked: 21 status checks all said
`running`, no I/O pauses. The longest UI hiccup was 2.1 seconds while the
catalogue was loading, nothing over 1.5 s during the actual installs.

## If it happens to you

Check free space on **both** the host and the guest, and look at what the
hypervisor says. A VM that got paused for a host I/O error needs space freed
on the host before you resume it. Updating the Store inside the VM won't
fix that.

There's a repeatable install test in `tests/store-install-smoke/`. Only run
it in a throwaway desktop session, it removes and reinstalls apps.
