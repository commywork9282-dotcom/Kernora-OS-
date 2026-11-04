# CPU temperature widget

The new desktop applet is `org.kernora.widget.cputemperature`. The existing
Plasma applet model discovers its metadata; Kernora's WidgetExplorer orders it
after Batteries. The search uses the normal model, including translated names
and descriptions. WidgetPreview uses the same TemperatureCard component as the
actual widget and labels its sample readings as a preview.

The applet subscribes to KDE's `org.kde.ksysguard.sensors` module, using
`cpu/all/maximumTemperature` by default and `cpu/all/averageTemperature` when
selected in settings. These are CPU-only aggregates provided by ksystemstats;
the widget does not mistake a GPU, SSD or motherboard sensor for CPU temperature.
The package explicitly depends on ksystemstats and its QML sensor module.

Readings are limited to one update per two seconds. The graph holds at most
60 samples, with gaps for missing readings; its vertical scale is 0–110 °C.
The peak is for this applet instance since startup or the last reading-mode
change. History is held in Celsius, so changing units preserves the same data.
Units and reading mode are saved using normal Plasma configuration. The applet
uses the current Material theme and has English and Russian labels.

KDE can report zero for an empty aggregate. Missing, nonnumeric, zero, negative,
nonfinite and implausibly high (200 °C or more) readings therefore show the
unavailable state instead of a misleading number. This widget is intended for
ordinary desktop CPU monitoring, not subzero cooling measurements. Actual
sensor availability remains dependent on kernel drivers and ksystemstats.

The owner approved stable publication on 2026-11-03. The stable packages are
`kernora-desktop` / `kernora-calamares` 1.4.55.1 and `kernora-apps` 1.1.64.1,
based on `main`. These versions advance stable without replacing the newer
Android demo packages. The update does not rebuild the ISO.
Screenshots are saved in `out/previews/cpu-temperature/`; the labelled sample
window is a rendering of the production card, not evidence of a real hardware
measurement. Tests and preview launcher are in `tests/cpu-temperature/`.

What's New is included in kernora-apps in English and Russian:

- EN: “CPU temperature widget — Add CPU temperature from the widget menu to
  see the hottest or average CPU reading, a two-minute history and the session
  peak. Choose Celsius or Fahrenheit in the widget settings. Computers without
  an available CPU sensor show an unavailable message.”
- RU: «Виджет температуры CPU — Добавьте его из меню виджетов, чтобы видеть
  самую высокую или среднюю температуру процессора, график за две минуты и
  максимум за время сеанса. В настройках доступны °C и °F. Если датчик CPU
  недоступен, виджет сообщит об этом».

## Preview validation

The source-package checks passed. In a disposable QEMU Live session with
Plasma 6.3.6 and Qt 6.8.2, nine QtTest cases passed after correcting compact
layout spacing. The installed applet loaded through the real Plasma applet
model and displayed the unavailable state on the virtual CPU. Its settings
opened through the normal context menu; selecting Fahrenheit and average
readings, applying, and restarting Plasma preserved both settings. The Russian
applet title and unavailable message were checked in the running desktop.
The production card was rendered in both light and dark themes using explicitly
labelled sample readings. Real CPU thermal hardware has not been validated in
this VM.

## Stable package validation

The approved update was built from main as desktop/calamares 1.4.55.1 and
apps 1.1.64.1. Source, binary-package, local APT archive and stable/demo
publishing tests passed. The three final packages installed successfully in a
fresh QEMU Live session, with no dpkg audit errors. The installed widget loaded
in Plasma and correctly reported the missing virtual CPU sensor; the installed
What’s New window displayed the new entry. Screenshots are in
`out/previews/cpu-temperature/stable-widget.png` and `stable-whatsnew.png`.

The publication archive retains all other stable artifacts byte for byte from
the previously published archive, avoiding replacement of unchanged versions
with locally rebuilt artifacts. The existing demo packages remain newer.
