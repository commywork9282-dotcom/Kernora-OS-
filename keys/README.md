# Key policy

`debian-trixie-fingerprints.txt` pins the public Debian archive keys used only
to authenticate the upstream snapshot.

`librewolf-fingerprint.txt` pins the LibreWolf repository key: it
authenticates the browser package the image installs, and the installed
system keeps it to take the browser's updates from that repository.

The distribution release key will be created after its identity is chosen.
Only its public key and fingerprint may live here. A private release key must
never be committed; `keys/private/` is ignored as an additional safeguard.

