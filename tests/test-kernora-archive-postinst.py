#!/usr/bin/env python3
import json
import os
from pathlib import Path
import subprocess
import tempfile
import unittest

POSTINST = Path(__file__).resolve().parents[1] / 'packages/native/kernora-archive/debian/kernora-archive.postinst'


class ArchiveConfiguration(unittest.TestCase):
    def configure(self, architecture='amd64', previous='', action='configure', enabled=(), fail=False):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            state = root / 'state.json'
            state.write_text(json.dumps({'architectures': list(enabled), 'calls': []}))
            dpkg = root / 'dpkg'
            dpkg.write_text('''#!/usr/bin/python3
import json,os,pathlib,subprocess,sys
args=sys.argv[1:]
p=pathlib.Path(os.environ['KERNORA_TEST_DPKG_STATE'])
s=json.loads(p.read_text())
if args==['--print-architecture']:
 print(os.environ['KERNORA_TEST_DPKG_ARCH'])
elif args[0]=='--compare-versions':
 sys.exit(subprocess.call(['/usr/bin/dpkg',*args]))
elif args==['--add-architecture','i386']:
 s['calls'].append(args)
 if os.environ['KERNORA_TEST_DPKG_FAIL']=='1':
  p.write_text(json.dumps(s));sys.exit(2)
 if 'i386' not in s['architectures']:s['architectures'].append('i386')
 p.write_text(json.dumps(s))
else:sys.exit(2)
''')
            dpkg.chmod(0o755)
            install = root / 'install'
            install.write_text('#!/bin/sh\nexit 0\n')
            install.chmod(0o755)
            env = dict(os.environ, PATH=str(root)+':'+os.environ['PATH'],
                       KERNORA_TEST_DPKG_STATE=str(state), KERNORA_TEST_DPKG_ARCH=architecture,
                       KERNORA_TEST_DPKG_FAIL='1' if fail else '0')
            result = subprocess.run(['/bin/sh', str(POSTINST), action, previous], env=env, capture_output=True)
            return result.returncode, json.loads(state.read_text())

    def test_fresh_amd64(self):
        code, state = self.configure()
        self.assertEqual(code, 0)
        self.assertEqual(state['architectures'], ['i386'])

    def test_upgrade_from_12(self):
        code, state = self.configure(previous='1.2')
        self.assertEqual(code, 0)
        self.assertEqual(state['architectures'], ['i386'])

    def test_existing_multiarch_preserved(self):
        code, state = self.configure(previous='1.2', enabled=['arm64', 'i386'])
        self.assertEqual(code, 0)
        self.assertEqual(state['architectures'], ['arm64', 'i386'])

    def test_reconfigure_preserves_deliberate_removal(self):
        code, state = self.configure(previous='1.3')
        self.assertEqual(code, 0)
        self.assertEqual(state['architectures'], [])
        self.assertEqual(state['calls'], [])

    def test_later_upgrade_preserves_removal(self):
        code, state = self.configure(previous='1.4')
        self.assertEqual(code, 0)
        self.assertEqual(state['calls'], [])

    def test_other_architecture_unchanged(self):
        code, state = self.configure(architecture='arm64', previous='1.2')
        self.assertEqual(code, 0)
        self.assertEqual(state['calls'], [])

    def test_abort_upgrade_unchanged(self):
        code, state = self.configure(previous='1.2', action='abort-upgrade')
        self.assertEqual(code, 0)
        self.assertEqual(state['calls'], [])

    def test_dpkg_failure_is_reported(self):
        code, state = self.configure(previous='1.2', fail=True)
        self.assertNotEqual(code, 0)
        self.assertEqual(state['architectures'], [])


if __name__ == '__main__':
    unittest.main()
