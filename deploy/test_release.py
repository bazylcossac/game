import hashlib
import io
import json
import os
from pathlib import Path
import tarfile
import tempfile
import unittest
from unittest.mock import Mock
from package_release import package
from release_install import extract_checked, Installer

SHA = "a" * 40
TAG = "panel-test"


class ReleaseTests(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.root = Path(self.temp.name)
        self.source = self.root / "source"
        for directory in ("scripts/core", "scripts/autoload", "assets", "shaders"):
            (self.source / directory).mkdir(parents=True, exist_ok=True)
        (self.source / "scripts/core/c.gd").write_text('const VERSION := "0.14.0"')
        (self.source / "scripts/autoload/net.gd").write_text("const AUTH_INFO = 2")
        (self.source / "main.tscn").write_text("test")
        (self.source / "project.godot").write_text("config_version=5")
        self.out = self.root / "out"
        package(self.source, self.out, TAG, SHA)
        self.archive = self.out / "MieczDawida-server-linux.tar.gz"
        self.digest = hashlib.sha256(self.archive.read_bytes()).hexdigest()

    def tearDown(self):
        self.temp.cleanup()

    def test_exact_identity_and_deterministic_package(self):
        again = self.root / "again"
        package(self.source, again, TAG, SHA)
        self.assertEqual(self.archive.read_bytes(), (again / self.archive.name).read_bytes())
        manifest = extract_checked(self.archive, self.root / "extracted", self.digest, TAG, SHA)
        self.assertEqual(manifest["commit"], SHA)
        self.assertEqual(manifest["gameVersion"], "0.14.0")
        self.assertEqual(json.loads((self.root / "extracted/panel-release.json").read_text()), manifest)

    def test_invalid_hash_and_wrong_revision_do_not_extract(self):
        for digest, sha in (("0" * 64, SHA), (self.digest, "b" * 40)):
            destination = self.root / "rejected"
            with self.assertRaises(ValueError):
                extract_checked(self.archive, destination, digest, TAG, sha)
            self.assertFalse(destination.exists())

    def test_tar_traversal_symlinks_duplicate_and_special_files_rejected(self):
        for name, kind in (("../outside", tarfile.REGTYPE), ("/etc/evil", tarfile.REGTYPE),
                           ("assets/link", tarfile.SYMTYPE), ("assets/dev", tarfile.CHRTYPE),
                           ("deploy/install.sh", tarfile.REGTYPE)):
            with tarfile.open(self.archive, "w:gz") as tar:
                member = tarfile.TarInfo(name)
                member.type = kind
                tar.addfile(member, io.BytesIO())
            digest = hashlib.sha256(self.archive.read_bytes()).hexdigest()
            with self.assertRaises(ValueError):
                extract_checked(self.archive, self.root / "unsafe", digest, TAG, SHA)
            self.assertFalse((self.root / "outside").exists())

    def test_versioned_tag_required(self):
        for tag in ("najnowsza", "../../evil", "bad;command", "-option"):
            with self.assertRaises(ValueError):
                package(self.source, self.out, tag, SHA)

    @unittest.skipIf(os.name == "nt", "Linux symlink/service layout")
    def test_failed_health_rolls_back_and_preserves_player_data(self):
        app = self.root / "app"
        (app / "game").mkdir(parents=True)
        (app / "game/original").write_text("old release")
        (app / "releases/new").mkdir(parents=True)
        player_data = self.root / "player-data"
        player_data.write_text("do not delete")
        installer = Installer(app)
        installer.command = Mock(return_value="")
        installer.health = Mock(side_effect=[RuntimeError("bad game"), {"version": "old"}])
        with self.assertRaisesRegex(RuntimeError, "restored and verified"):
            installer.switch(app / "releases/new", "test-id", "new")
        self.assertTrue((app / "game").is_symlink())
        self.assertEqual((app / "game/original").read_text(), "old release")
        self.assertEqual(player_data.read_text(), "do not delete")
        self.assertEqual(installer.health.call_count, 2)

    @unittest.skipIf(os.name == "nt", "Linux symlink/service layout")
    def test_success_keeps_previous_release_available(self):
        app = self.root / "app"
        (app / "releases/old").mkdir(parents=True)
        (app / "releases/new").mkdir()
        (app / "game").symlink_to(app / "releases/old")
        installer = Installer(app)
        installer.command = Mock(return_value="")
        installer.health = Mock(return_value={"version": "new"})
        self.assertEqual(installer.switch(app / "releases/new", "test-id", "new"), {"version": "new"})
        self.assertEqual((app / "game").resolve(), app / "releases/new")
        self.assertTrue((app / "releases/old").exists())


if __name__ == "__main__":
    unittest.main()
