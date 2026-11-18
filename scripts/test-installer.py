#!/usr/bin/env python3
"""Installer preflight integration tests: temporary volumes, never real apps."""
import plistlib
import shutil
import subprocess
import tempfile
import unittest
from pathlib import Path


class InstallerFixture(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory(prefix="codexneko-installer-test-")
        self.root = Path(self.temp.name)
        self.volume = self.root / "Test Volume"
        self.volume.mkdir()
        self.app = self.volume / "Applications/CodexNeko.app"
        self.legacy = self.volume / "Applications/MultiCodex.app"
        self.backups = self.volume / "Library/Application Support/CodexNeko/Previous Versions"
        self.scripts = self.root / "Package Scripts"
        self.scripts.mkdir()
        for name in ["preinstall", "postinstall", "common.sh"]:
            shutil.copy2(Path(__file__).parent / "installer" / name, self.scripts / name)
        (self.scripts / "Version.plist").write_bytes(plistlib.dumps({
            "CFBundleShortVersionString": "1.0.0", "CFBundleVersion": "4",
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

    def installed(self, version="1.0.0", build="1", identifier="com.coradini.multicodex.manager", path=None, signed=False):
        app = path or self.app
        (app / "Contents").mkdir(parents=True)
        (app / "Contents/Info.plist").write_bytes(plistlib.dumps({
            "CFBundleIdentifier": identifier, "CFBundleShortVersionString": version, "CFBundleVersion": build,
            "CFBundleExecutable": "CodexNeko", "CFBundlePackageType": "APPL", "CFBundleName": "CodexNeko",
        }))
        (app / "Contents/Resources").mkdir()
        (app / "Contents/Resources/old-resource.txt").write_text("installed-app-marker")
        if signed:
            (app / "Contents/MacOS").mkdir()
            shutil.copyfile("/usr/bin/true", app / "Contents/MacOS/CodexNeko")
            (app / "Contents/MacOS/CodexNeko").chmod(0o755)
            subprocess.run(["/usr/bin/codesign", "--force", "--sign", "-", str(app)], check=True, capture_output=True)
        return app

    def run_preflight(self, expected):
        before = self.snapshot()
        result = subprocess.run(["/bin/bash", str(self.scripts / "preinstall"), "test.pkg", "/", str(self.volume)],
                                capture_output=True, text=True, timeout=10)
        self.assertEqual(result.returncode, expected, result.stdout + result.stderr)
        self.assertEqual(before, self.snapshot(), "Preflight changed an app or user data")
        self.assertEqual(self.credentials.read_text(), "synthetic-login-marker")
        self.assertEqual(plistlib.loads(self.preferences.read_bytes())["mascot.variant"], "female")
        return result.stdout + result.stderr


class InstallerTests(InstallerFixture):
    def test_fresh_install(self):
        self.assertIn("nova instalação", self.run_preflight(0))

    def test_upgrade_detects_existing_build(self):
        self.installed(build="1")
        self.assertIn("atualização detectada", self.run_preflight(0))

    def test_reinstall_same_version_is_allowed(self):
        self.installed(build="4")
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

    def test_former_app_name_is_recognized(self):
        self.installed(path=self.legacy, build="3")
        self.assertIn("atualização detectada", self.run_preflight(0))

    def test_newer_former_app_blocks_downgrade(self):
        self.installed(path=self.legacy, build="10")
        self.assertIn("mais nova", self.run_preflight(1))

    def test_unrelated_former_app_is_preserved(self):
        self.installed(path=self.legacy, identifier="com.example.other")
        self.assertIn("Outro aplicativo", self.run_preflight(1))

    def test_both_names_are_checked_for_newer_versions(self):
        self.installed(build="2")
        self.installed(path=self.legacy, build="10")
        self.assertIn("mais nova", self.run_preflight(1))


class MigrationTests(InstallerFixture):
    def run_migration(self, expected):
        before = self.snapshot()
        result = subprocess.run(["/bin/bash", str(self.scripts / "postinstall"), "test.pkg", "/", str(self.volume)],
                                capture_output=True, text=True, timeout=10)
        self.assertEqual(result.returncode, expected, result.stdout + result.stderr)
        self.assertEqual(self.credentials.read_text(), "synthetic-login-marker")
        self.assertEqual(plistlib.loads(self.preferences.read_bytes())["mascot.variant"], "female")
        if expected != 0:
            self.assertEqual(before, self.snapshot(), "A rejected migration changed an app or user data")
        return result.stdout + result.stderr

    def setup_upgrade(self):
        self.installed(build="4", signed=True)
        self.installed(path=self.legacy, build="3")

    def test_former_bundle_is_backed_up_after_verified_install(self):
        self.setup_upgrade()
        old_info = (self.legacy / "Contents/Info.plist").read_bytes()
        self.assertIn("versão anterior guardada", self.run_migration(0))
        self.assertFalse(self.legacy.exists())
        archived = list(self.backups.glob("*/MultiCodex.app"))
        self.assertEqual(len(archived), 1)
        self.assertEqual((archived[0] / "Contents/Info.plist").read_bytes(), old_info)
        self.assertEqual((archived[0] / "Contents/Resources/old-resource.txt").read_text(), "installed-app-marker")
        self.assertTrue(self.app.exists())

    def test_fresh_install_needs_no_backup(self):
        self.installed(build="4", signed=True)
        before = self.snapshot()
        self.run_migration(0)
        self.assertEqual(before, self.snapshot())
        self.assertFalse(self.backups.exists())

    def test_newer_former_bundle_is_preserved(self):
        self.installed(build="4", signed=True)
        self.installed(path=self.legacy, build="10")
        self.assertIn("mais nova", self.run_migration(1))

    def test_unsigned_replacement_never_archives_previous_app(self):
        self.installed(build="4")
        self.installed(path=self.legacy, build="3")
        self.assertIn("assinatura", self.run_migration(1))
        self.assertTrue(self.legacy.exists())

    def test_missing_replacement_never_archives_previous_app(self):
        self.installed(path=self.legacy, build="3")
        self.run_migration(1)
        self.assertTrue(self.legacy.exists())

    def test_unrelated_replacement_never_archives_previous_app(self):
        self.installed(build="4", identifier="com.example.other", signed=True)
        self.installed(path=self.legacy, build="3")
        self.assertIn("Outro aplicativo", self.run_migration(1))

    def test_backup_symlink_is_never_followed(self):
        self.setup_upgrade()
        parent = self.backups.parent
        parent.parent.mkdir(parents=True)
        target = self.root / "Unrelated Files"
        target.mkdir()
        parent.symlink_to(target, target_is_directory=True)
        self.assertIn("link simbólico", self.run_migration(1))
        self.assertEqual(list(target.iterdir()), [])

    def test_insecure_backup_folder_preserves_previous_app(self):
        self.setup_upgrade()
        self.backups.mkdir(parents=True)
        self.backups.chmod(0o777)
        self.assertIn("outros usuários", self.run_migration(1))

    def test_existing_backups_are_preserved_and_second_run_is_idle(self):
        self.setup_upgrade()
        previous = self.backups / "previous-existing/marker.txt"
        previous.parent.mkdir(parents=True)
        previous.write_text("keep-existing-backup")
        self.run_migration(0)
        self.assertEqual(previous.read_text(), "keep-existing-backup")
        before = self.snapshot()
        self.run_migration(0)
        self.assertEqual(before, self.snapshot())


if __name__ == "__main__":
    unittest.main(verbosity=2)
