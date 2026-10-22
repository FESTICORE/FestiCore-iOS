import importlib.util
from pathlib import Path
import subprocess
import tempfile
import unittest


SCRIPT = Path(__file__).with_name("sync-design-tokens.py")
SPEC = importlib.util.spec_from_file_location("sync_design_tokens", SCRIPT)
sync = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(sync)


class SyncDesignTokensTests(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.addCleanup(self.temp.cleanup)
        self.root = Path(self.temp.name)
        self.source = self.root / "source"
        self.source.mkdir()
        for name in sync.EXPECTED_SOURCES:
            self.put(f"generated/ios/Sources/{name}", "import UIKit\n")
        self.put("generated/ios/Assets/FestiCoreColors.xcassets/Contents.json", "{}\n")
        self.put("generated/ios/Assets/FestiCoreColors.xcassets/primaryNormal.colorset/Contents.json", "{}\n")
        self.put("tokens/$themes.json", "{}\n")
        subprocess.run(["git", "init", "-q", str(self.source)], check=True)
        subprocess.run(["git", "-C", str(self.source), "add", "."], check=True)
        subprocess.run(
            ["git", "-C", str(self.source), "-c", "user.name=Test", "-c", "user.email=test@example.com", "commit", "-qm", "fixture"],
            check=True,
        )
        self.sha = subprocess.check_output(
            ["git", "-C", str(self.source), "rev-parse", "HEAD"], text=True
        ).strip()

    def put(self, relative, content):
        path = self.source / relative
        path.parent.mkdir(parents=True, exist_ok=True)
        path.write_text(content, encoding="utf-8")

    def test_import_and_digest_are_stable(self):
        destination = self.root / "Generated"
        sync.import_tokens(self.source, destination, self.sha)
        first = sync.snapshot_digest(destination, self.sha)
        sync.import_tokens(self.source, destination, self.sha)
        self.assertEqual(first, sync.snapshot_digest(destination, self.sha))
        self.assertEqual((destination / ".source-sha").read_text(), self.sha + "\n")

    def test_wrong_sha_and_unexpected_path_are_rejected(self):
        with self.assertRaisesRegex(ValueError, "does not match"):
            sync.import_tokens(self.source, self.root / "Generated", "0" * 40)
        self.put("generated/ios/run.sh", "echo unsafe\n")
        with self.assertRaisesRegex(ValueError, "Unexpected generated path"):
            sync.import_tokens(self.source, self.root / "Generated", self.sha)

    def test_symlink_is_rejected(self):
        (self.source / "generated/ios/Sources/extra.swift").symlink_to("FestiCoreColor.swift")
        with self.assertRaisesRegex(ValueError, "ordinary, unlinked file"):
            sync.import_tokens(self.source, self.root / "Generated", self.sha)

    def test_changed_snapshot_is_rejected(self):
        destination = self.root / "Generated"
        sync.import_tokens(self.source, destination, self.sha)
        (destination / "Tokens/$themes.json").write_text("{\"changed\":true}\n")
        self.assertNotEqual(sync.snapshot_digest(destination, self.sha), sync.snapshot_digest(self._fresh_snapshot(), self.sha))

    def _fresh_snapshot(self):
        destination = self.root / "Fresh"
        sync.import_tokens(self.source, destination, self.sha)
        return destination


if __name__ == "__main__":
    unittest.main()
