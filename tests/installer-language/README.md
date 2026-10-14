# Installer language regression

Run in a Kernora Live session with the native installer packages installed:

```sh
sudo python3 tests/installer-language/run.py --output /tmp/installer-language.log
```

The test copies the installed branding to a temporary directory and loads
the actual Calamares welcome, locale and keyboard modules. Its configuration
has no execution sequence or installation jobs. It changes the welcome
language between English, Russian and German, chooses Russian from the locale
page, and goes back to choose English again. It checks bound QML text,
translated C++ status, sidebar labels, translated city names, both selectors, and the final
target `localeConf` while retaining independently chosen German formats.

It exits with an error on a failed check or a bounded timeout. Headless
keyboard/display warnings do not determine the result; the explicit
`KERNORA_LANGUAGE_SMOKE_PASS` marker does. The package before this change
fails when the locale page changes its target language without translating
the installer.
