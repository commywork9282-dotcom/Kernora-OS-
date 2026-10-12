#!/usr/bin/env bash
set -Eeuo pipefail
if pgrep -x kernora-store >/dev/null; then
    printf 'Close Store before running the launcher regression.\n' >&2
    exit 1
fi
fixture=$(mktemp -d)
trap 'rm -rf -- "$fixture"' EXIT
mkdir -p "$fixture/bin" "$fixture/share/applications"
export KERNORA_LAUNCH_TEST_OUT="$fixture/called"
cat > "$fixture/bin/flatpak" <<'STUB'
#!/bin/sh
printf '%s\n' "$@" > "$KERNORA_LAUNCH_TEST_OUT"
STUB
cat > "$fixture/bin/native" <<'STUB'
#!/bin/sh
printf 'wrong-native-launch\n' > "$KERNORA_LAUNCH_TEST_OUT"
STUB
chmod +x "$fixture/bin/flatpak" "$fixture/bin/native"
for desktop in org.telegram.desktop org.telegram.desktop.desktop telegram.desktop; do
    cat > "$fixture/share/applications/$desktop" <<DESKTOP
[Desktop Entry]
Type=Application
Name=Native launcher collision fixture
Exec=$fixture/bin/native
DESKTOP
done
XDG_DATA_HOME="$fixture/share" PATH="$fixture/bin:$PATH" \
    KERNORA_QML_STORE="$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)" \
    timeout 150 kernora-store > "$fixture/launch.log" 2>&1
cat "$fixture/launch.log"
grep -Fq STORE_LAUNCH_STARTED "$fixture/launch.log"
cat "$fixture/called"
python3 - "$fixture/called" <<'PY'
import pathlib,sys
args=pathlib.Path(sys.argv[1]).read_text().splitlines()
assert args[0]=='run', args
assert args[1] in ('--user','--system'), args
refs=[arg for arg in args if arg.startswith('app/org.telegram.desktop/')]
assert len(refs)==1 and len(refs[0].split('/'))==4, args
export=pathlib.Path('/var/lib/flatpak/exports/share/applications/org.telegram.desktop.desktop')
if args[1]=='--system' and export.exists():
    import shlex
    command=next(line[5:] for line in export.read_text().splitlines() if line.startswith('Exec='))
    for arg in shlex.split(command):
        if arg.startswith('--command='):
            assert arg in args, (arg,args)
print('STORE_LAUNCH_OK: installed scope/ref used despite native desktop collision:', args)
PY
