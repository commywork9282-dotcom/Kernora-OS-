# Distribution packages

- `native/` — packages created by this distribution (identity, keyring,
  metapackages, defaults, update policy).
- `derived/` — Debian source packages that are intentionally changed. Each
  package must retain Debian copyright/changelog data and record its upstream
  version and patch provenance.

Unchanged Debian sources are not copied into Git. Their exact `.dsc` and
tarballs are pinned in `manifests/upstream.lock` and cached under
`_cache/upstream-sources/`.

