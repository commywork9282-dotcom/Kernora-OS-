# ADR 0001: archive-first derivative model

Status: accepted for Stage 0

We will not treat a remastered ISO as the distribution. The project owns an
APT archive and source packages; root filesystems and installation media are
outputs of that archive.

A complete mirror of all Debian source packages is unnecessary and exceeds
the current storage budget. Sources are fetched from a timestamped Debian
snapshot according to explicit manifests and cached locally.

