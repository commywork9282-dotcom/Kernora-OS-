# Locale generation and Philippine regions

Live builds previously replaced `/etc/locale.gen` with two enabled entries:
`en_US.UTF-8` and `ru_RU.UTF-8`. Calamares 3.3.14 enables selected locales by
matching entries already present in that file. A Philippine region could
therefore be written to `/etc/default/locale` without being generated. Bash
then printed `cannot change locale (en_PH.UTF-8)` and libc fell back to ASCII.

`kernora-locales --prepare` now restores missing catalog entries from Debian's
`/usr/share/i18n/SUPPORTED` as comments while preserving existing entries. Live
builds explicitly enable English and Russian from that catalog. Calamares runs
`kernoralocales` after `localecfg`; it repairs every supported selection written
to the target using Debian's actual locale/charmap pair. This also handles
`fil_PH UTF-8`, whose SUPPORTED entry has no `.UTF-8` suffix. Running after the
stock job also covers its restoration of a pre-existing `locale.gen.bak`.

On package configuration, `kernora-locales` reads `/etc/default/locale`,
`/etc/locale.conf`, and the `[Formats]` section of ordinary local users'
`plasma-localerc`. It enables supported selected locales and generates missing
active UTF-8 locales using `locale-gen --keep-existing`. It verifies the result
with `locale -a`; a zero generator exit status alone is insufficient. It does
not change language or format preferences. Repeated runs make no changes when
the catalog and generated locales are complete. No login hook is installed.

The root cause was reproduced in a disposable Debian/Kernora QEMU session with
the installed Calamares module. Before repair, the actual rewrite recorded
`# Missing: en_PH.UTF-8`, Bash warned, and `locale charmap` returned
`ANSI_X3.4-1968`. After repair, `en_PH.UTF-8` and `fil_PH.UTF-8` returned `UTF-8`
with no warnings and `localeconv()` reported `PHP`. The installer preparation
plus the real Calamares rewrite also passed for these locales, Tagalog and
German. Existing preferences and repeated-run idempotence were checked.

Run `python3 tests/locales/run.py` for the ten file, selection, generator-failure
and installer checks. Native logs are in `out/test-logs/locales/`.

Sources:

- [Calamares 3.3.14 locale rewriting](https://github.com/calamares/calamares/blob/v3.3.14/src/modules/localecfg/main.py)
- [KDE locale generator helper](https://github.com/KDE/plasma-workspace/blob/Plasma/6.3/kcms/region_language/localegenhelper/localegenhelper.cpp)

Stable package versions: desktop/calamares `1.4.55.3`, apps `1.1.64.3`.
The demo backport uses `1.4.66.1` / `1.1.76.1`, preserving published Android
features and leaving the pending Android update separate. Both carry the
English/Russian What's New entry `2026-11-04-2`.
