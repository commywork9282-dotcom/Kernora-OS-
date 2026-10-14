import argparse
import os
import pathlib
import shutil
import subprocess
import tempfile
import time

parser = argparse.ArgumentParser()
parser.add_argument('--output', required=True)
args = parser.parse_args()
fixtures = pathlib.Path(__file__).resolve().parent
with tempfile.TemporaryDirectory(prefix='kernora-installer-language-') as temporary:
    root = pathlib.Path(temporary)
    (root / 'modules').mkdir()
    shutil.copytree('/etc/calamares/branding/kernora', root / 'branding/kernora')
    (root / 'qml').symlink_to('/usr/share/calamares/qml')
    (root / 'settings.conf').write_text('modules-search: [ local, /usr/lib/calamares/modules ]\nsequence:\n- show: [welcomeq, localeq, keyboardq]\nbranding: kernora\nprompt-install: false\ndont-chroot: true\n')
    (root / 'modules/welcomeq.conf').write_text('requirements:\n  check: []\n  required: []\n')
    (root / 'modules/localeq.conf').write_text('adjustLiveTimezone: false\n')
    for name in ('welcome', 'locale'):
        path = root / f'branding/kernora/{name}q.qml'
        source = path.read_text()
        position = source.rfind('}')
        path.write_text(source[:position] + (fixtures / f'{name}-audit.qml.inc').read_text() + source[position:])
    output = pathlib.Path(args.output)
    env = dict(os.environ, LANG='en_US.UTF-8', LANGUAGE='en_US', LC_ALL='en_US.UTF-8', QT_QPA_PLATFORM='offscreen', QT_QUICK_BACKEND='software', QT_QUICK_CONTROLS_STYLE='org.kernora.desktop')
    with output.open('w') as log:
        process = subprocess.Popen(['calamares', '-d', '-c', str(root)], env=env, stdout=log, stderr=subprocess.STDOUT)
        try:
            deadline = time.monotonic() + 45
            while time.monotonic() < deadline:
                text = output.read_text(errors='replace')
                if 'KERNORA_LANGUAGE_FAIL:' in text:
                    raise SystemExit('Installer language regression failed; see ' + str(output))
                if 'KERNORA_LANGUAGE_SMOKE_PASS:' in text:
                    print('Installer language regression: PASS')
                    break
                if process.poll() is not None:
                    raise SystemExit('Calamares exited before completing the language regression')
                time.sleep(0.2)
            else:
                raise SystemExit('Installer language regression timed out; see ' + str(output))
        finally:
            process.terminate()
            try:
                process.wait(timeout=5)
            except subprocess.TimeoutExpired:
                process.kill()
                process.wait()
