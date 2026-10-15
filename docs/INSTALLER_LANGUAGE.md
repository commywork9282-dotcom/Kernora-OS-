# Live and installer language

## Boot menu

The Live GRUB menu has stable entry ids: `live-en`, `live-ru` and
`live-safe`. English is first and it's the default, Russian is right under
it. Safe graphics boots in English too. If the ISO finds an installed Kernora
on the disk, the `installed` entry still wins.

The Live language service applies the chosen kernel argument before login,
so the system locale and Plasma's translation settings are right from the
start. Both English and Russian locales are generated in the image.

## Calamares

The welcome page language picker always translated the installer. The one on
the location page only changed the language of the system being installed,
which was confusing. Now the patched `calamares` package switches the
installer's translation there too, and the welcome picker follows it when
you go back. Picking a language on the welcome page again also updates the
target language. Regional formats you chose separately stay as they are.

To make that work, the region and timezone models tell their views when the
language changes, the city list refreshes and re-sorts its translated names,
and the sidebar labels refresh when the translator changes.

The full target locale is kept even when Calamares uses a more general
translation, like `ru_RU.UTF-8` with the `ru` translation. Missing
translations fall back the normal Calamares way, this doesn't add any new
ones.

Packages:

- `calamares 3.3.14-1kernora2`: language switching and translated models
- `kernora-desktop` / `kernora-calamares 1.4.28`: config dependency and the
  city list refresh
- `kernora-apps 1.1.35`: What's New entry `2026-10-13-8`, English and Russian

## Testing

There's a regression test in [tests/installer-language](../tests/installer-language/README.md).
It loads the real Calamares modules with temporary branding and no install
jobs. The old package failed it right at the location page language change.
The new one passes EN → RU → DE → EN switching, Russian picked on the
location page, going back to the welcome page, city names, sidebar labels,
and the final `LANG` with separate `LC_*` formats kept. The sidebar check
also failed before I added the model notification, so it actually catches
that bug.

Besides that: package checks, `make verify`, archive and live rootfs checks,
and BIOS/UEFI boot in QEMU. A default boot got to Plasma with
`LANG=en_US.UTF-8` and English translations, the second GRUB entry got to
Plasma in Russian. I didn't redo a full install to disk for this change.

Note that the Live default is part of the ISO boot menu, so updating an
installed system obviously can't change an old USB stick. Reflash it with a
newer ISO to get the English default.
