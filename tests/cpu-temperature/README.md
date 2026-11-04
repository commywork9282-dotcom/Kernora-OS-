# CPU temperature widget checks

Run `tests/cpu-temperature/run.sh` inside a Kernora Plasma session with
`qml-qt6`, `qt6-declarative-dev-tools` and `qml6-module-qttest` installed.
The test copies the actual source card into an isolated directory and checks
Celsius/Fahrenheit conversion, unavailable readings, graph gaps and layout at
normal, minimum and enlarged sizes, including Russian labels. Image checks
allow fractional display scaling.

`tests/cpu-temperature/run.sh --preview` opens the actual card in three states.
The window explicitly identifies its readings as samples. It does not replace
the installed widget's sensor or alter real CPU readings.

The desktop integration also needs a manual/native check: search for CPU in
Add or Manage Widgets, add the Kernora card, open its settings, change the
units and reading mode, then restart Plasma and verify the configuration.
Without a CPU sensor (for example in QEMU), the widget must show an em dash and
an unavailable label, never the sample temperature from the menu preview.
