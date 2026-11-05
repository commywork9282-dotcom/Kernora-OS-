#!/usr/bin/env python3
import pathlib
import contextlib
import io
import runpy
import subprocess
import sys
import tempfile
import types
import unittest
from unittest import mock

PROJECT = pathlib.Path(__file__).resolve().parents[2]
HELPER = PROJECT / "packages/native/kernora-desktop/data/locales/kernora-locales"
API = runpy.run_path(str(HELPER))
SUPPORTED = "en_US.UTF-8 UTF-8\nru_RU.UTF-8 UTF-8\nen_PH.UTF-8 UTF-8\nen_PH ISO-8859-1\nfil_PH UTF-8\ntl_PH.UTF-8 UTF-8\nde_DE.UTF-8 UTF-8\n"


class LocalesTest(unittest.TestCase):
    def setUp(self):
        self.temporary = tempfile.TemporaryDirectory()
        self.addCleanup(self.temporary.cleanup)
        self.root = pathlib.Path(self.temporary.name)
        for directory in ("etc/default", "usr/share/i18n", "home/person/.config"):
            (self.root / directory).mkdir(parents=True, exist_ok=True)
        (self.root / "usr/share/i18n/SUPPORTED").write_text(SUPPORTED)
        (self.root / "etc/locale.gen").write_text("en_US.UTF-8 UTF-8\nru_RU.UTF-8 UTF-8\n")
        (self.root / "etc/passwd").write_text("person:x:1000:1000::/home/person:/bin/bash\n")

    def active(self):
        return {line for line in (self.root / "etc/locale.gen").read_text().splitlines() if line and not line.startswith("#")}

    def test_restore_catalog_without_enabling_all_locales(self):
        API["prepare"](self.root, [])
        self.assertEqual(self.active(), {"en_US.UTF-8 UTF-8", "ru_RU.UTF-8 UTF-8"})
        self.assertIn("# en_PH.UTF-8 UTF-8", (self.root / "etc/locale.gen").read_text())
        self.assertIn("# fil_PH UTF-8", (self.root / "etc/locale.gen").read_text())

    def test_philippines_names_and_encoding_aliases(self):
        for value, expected in (("en_PH.utf8", "en_PH.UTF-8 UTF-8"), ("fil_PH.UTF-8", "fil_PH UTF-8"), ("tl_PH", "tl_PH.UTF-8 UTF-8")):
            API["prepare"](self.root, [value])
            self.assertIn(expected, self.active())

    def test_idempotent_and_preserves_custom_entries(self):
        path = self.root / "etc/locale.gen"
        path.write_text(path.read_text() + "\n# Personal setting\nen_PH ISO-8859-1\n")
        path.chmod(0o640)
        API["prepare"](self.root, ["en_PH.UTF-8"])
        first = path.read_bytes()
        API["prepare"](self.root, ["en_PH.UTF-8"])
        self.assertEqual(path.read_bytes(), first)
        self.assertIn("en_PH ISO-8859-1", self.active())
        self.assertEqual(path.stat().st_mode & 0o777, 0o640)

    def test_rejects_unknown_locale_without_modifying_file(self):
        path = self.root / "etc/locale.gen"
        first = path.read_bytes()
        with self.assertRaises(ValueError):
            API["prepare"](self.root, ["en_PH.UTF-8;touch /tmp/not-a-command"])
        self.assertEqual(path.read_bytes(), first)

    def test_builtin_locales(self):
        API["prepare"](self.root, ["C", "C.UTF-8", "POSIX"])
        self.assertEqual(self.active(), {"en_US.UTF-8 UTF-8", "ru_RU.UTF-8 UTF-8"})

    def test_reads_system_and_user_formats_without_changing_them(self):
        system = self.root / "etc/default/locale"
        plasma = self.root / "home/person/.config/plasma-localerc"
        system.write_text('LANG="en_US.UTF-8"\nLC_CTYPE=en_PH.UTF-8\nLC_COLLATE=en_PH.UTF-8\n')
        plasma.write_text("[Formats]\nLANG=fil_PH.UTF-8\nLC_TIME=tl_PH.UTF-8\n[Translations]\nLANGUAGE=fil:en_US\n")
        originals = {p: p.read_bytes() for p in (system, plasma)}
        selected = API["configured_locales"](self.root)
        self.assertEqual(selected, {"en_US.UTF-8", "en_PH.UTF-8", "fil_PH.UTF-8", "tl_PH.UTF-8"})
        API["prepare"](self.root, selected)
        for path, text in originals.items():
            self.assertEqual(path.read_bytes(), text)

    def test_repair_generates_and_verifies_missing_locale(self):
        (self.root / "etc/default/locale").write_text("LANG=en_US.UTF-8\nLC_CTYPE=en_PH.UTF-8\nLC_COLLATE=en_PH.UTF-8\n")
        calls = []
        def command(root, args):
            calls.append(args)
            names = "en_US.utf8\nru_RU.utf8\n"
            if len(calls) >= 3:
                names += "en_PH.utf8\n"
            return subprocess.CompletedProcess(args, 0, names if args[-1] == "-a" else "Generated\n", "")
        with mock.patch.dict(API["repair"].__globals__, command=command), contextlib.redirect_stdout(io.StringIO()):
            API["repair"](self.root)
        self.assertEqual(calls, [["/usr/bin/locale", "-a"], ["/usr/sbin/locale-gen", "--keep-existing"], ["/usr/bin/locale", "-a"]])
        self.assertIn("en_PH.UTF-8 UTF-8", self.active())

    def test_repair_does_not_accept_false_generator_success(self):
        (self.root / "etc/default/locale").write_text("LANG=en_PH.UTF-8\n")
        def command(root, args):
            return subprocess.CompletedProcess(args, 0, "en_US.utf8\nru_RU.utf8\n", "")
        with mock.patch.dict(API["repair"].__globals__, command=command), contextlib.redirect_stdout(io.StringIO()):
            with self.assertRaisesRegex(RuntimeError, "en_PH"):
                API["repair"](self.root)

    def test_installer_repairs_selected_locales_after_stock_configuration(self):
        settings = {"rootMountPoint": str(self.root)}
        (self.root / "etc/default/locale").write_text("LANG=en_US.UTF-8\nLC_CTYPE=en_PH.UTF-8\nLC_COLLATE=en_PH.UTF-8\nLC_TIME=fil_PH.UTF-8\n")
        fake = types.SimpleNamespace(globalstorage=types.SimpleNamespace(value=settings.get),
                                     utils=types.SimpleNamespace(gettext_path=lambda: "/usr/share/locale", gettext_languages=lambda: ["en_US"]))
        path = PROJECT / "packages/native/kernora-desktop/data/calamares/modules/kernoralocales/main.py"
        with mock.patch.dict(sys.modules, libcalamares=fake):
            module = runpy.run_path(str(path))
        calls = []
        def command(root, args):
            calls.append(args)
            names = "en_US.utf8\nru_RU.utf8\n"
            if len(calls) >= 3:
                names += "en_PH.utf8\nfil_PH.utf8\n"
            return subprocess.CompletedProcess(args, 0, names if args[-1] == "-a" else "", "")
        def run(args, **kwargs):
            self.assertEqual(args, ["/usr/libexec/kernora-locales", "--root", str(self.root)])
            API["repair"](self.root)
            return subprocess.CompletedProcess(args, 0, "", "")
        with mock.patch.object(subprocess, "run", run), mock.patch.dict(API["repair"].__globals__, command=command):
            self.assertIsNone(module["run"]())
        self.assertIn("en_PH.UTF-8 UTF-8", self.active())
        self.assertIn("fil_PH UTF-8", self.active())
        self.assertIn(["/usr/sbin/locale-gen", "--keep-existing"], calls)
        config = (PROJECT / "packages/native/kernora-desktop/data/calamares/settings.conf").read_text()
        self.assertLess(config.index("  - localecfg\n"), config.index("  - kernoralocales\n"))

    def test_cli_prepare_never_generates_locales(self):
        result = subprocess.run([sys.executable, str(HELPER), "--root", str(self.root), "--prepare", "--enable", "en_PH.UTF-8"], capture_output=True, text=True)
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertIn("en_PH.UTF-8 UTF-8", self.active())


if __name__ == "__main__":
    unittest.main(verbosity=2)
