#!/usr/bin/env python3
"""Installer preflight integration tests: temporary volumes, never real apps."""
import plistlib
import shutil
import subprocess
import tempfile
import unittest
from pathlib import Path


class InstallerTests(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory(prefix="multicodex-installer-test-")
        self.root = Path(self.temp.name)
        self.volume = self.root / "Test Volume"
        self.volume.mkdir()
        self.app = self.volume / "Applications/MultiCodex.app"
        self.scripts = self.root / "Package Scripts"
        self.scripts.mkdir()
        shutil.copy2(Path(__file__).parent / "installer/preinstall", self.scripts / "preinstall")
        (self.scripts / "Version.plist").write_bytes(plistlib.dumps({
            "CFBundleShortVersionString": "1.0.0", "CFBundleVersion": "2",
        }))
        self.credentials = self.volume / "Users/Test User/Library/Application Support/Multi Codex/profiles/2/codex/auth.json"
        self.credentials.parent.mkdir(parents=True)
        self.credentials.write_text("synthetic-login-marker")
        self.preferences = self.volume / "Users/Test User/Library/Preferences/com.coradini.multicodex.manager.plist"
        self.preferences.parent.mkdir(parents=True)
        self.preferences.write_bytes(plistlib.dumps({"mascot.variant": "female"}))
        self.before = self.snapshot()

    def tearDown(self):
        self.temp.cleanup()

    def snapshot(self):
        return {str(path.relative_to(self.volume)): path.read_bytes() for path in self.volume.rglob("*") if path.is_file()}

    def installed(self, version="1.0.0", build="1", identifier="com.coradini.multicodex.manager"):
        (self.app / "Contents").mkdir(parents=True)
        (self.app / "Contents/Info.plist").write_bytes(plistlib.dumps({
            "CFBundleIdentifier": identifier, "CFBundleShortVersionString": version, "CFBundleVersion": build,
        }))
        (self.app / "Contents/old-resource.txt").write_text("installed-app-marker")

    def run_preflight(self, expected):
        before = self.snapshot()
        result = subprocess.run(["/bin/bash", str(self.scripts / "preinstall"), "test.pkg", "/", str(self.volume)],
                                capture_output=True, text=True, timeout=10)
        self.assertEqual(result.returncode, expected, result.stdout + result.stderr)
        self.assertEqual(before, self.snapshot(), "Preflight changed an app or user data")
        self.assertEqual(self.credentials.read_text(), "synthetic-login-marker")
        self.assertEqual(plistlib.loads(self.preferences.read_bytes())["mascot.variant"], "female")
        return result.stdout + result.stderr

    def test_fresh_install(self):
        self.assertIn("nova instalação", self.run_preflight(0))

    def test_upgrade_detects_existing_build(self):
        self.installed(build="1")
        self.assertIn("atualização detectada", self.run_preflight(0))

    def test_reinstall_same_version_is_allowed(self):
        self.installed(build="2")
        self.assertIn("reinstalando", self.run_preflight(0))

    def test_newer_build_blocks_downgrade(self):
        self.installed(build="10")
        self.assertIn("mais nova", self.run_preflight(1))

    def test_newer_version_blocks_downgrade(self):
        self.installed(version="1.0.10", build="1")
        self.assertIn("mais nova", self.run_preflight(1))

    def test_older_version_allows_update_even_with_higher_build(self):
        self.installed(version="0.9.9", build="99")
        self.assertIn("atualização detectada", self.run_preflight(0))

    def test_another_application_is_never_overwritten(self):
        self.installed(identifier="com.example.another-app")
        self.assertIn("Outro aplicativo", self.run_preflight(1))

    def test_symbolic_link_target_is_not_followed(self):
        self.app.parent.mkdir(parents=True)
        target = self.root / "Another App"
        target.mkdir()
        self.app.symlink_to(target, target_is_directory=True)
        self.assertIn("não é um aplicativo válido", self.run_preflight(1))

    def test_malformed_version_does_not_modify_installation(self):
        self.installed(version="unknown")
        self.assertIn("metadados inválidos", self.run_preflight(1))


if __name__ == "__main__":
    unittest.main(verbosity=2)
