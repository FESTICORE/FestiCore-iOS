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
        for name in sync.SOURCE_PATHS:
            self.put(f"generated/ios/Sources/{name}", sync.generated_header(name) + "import UIKit\n")
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
        self.assertEqual((destination / sync.SHA_PATH).read_text(), self.sha + "\n")
        self.assertTrue((destination / sync.SOURCE_PATHS["FestiCoreSemanticColor.swift"]).is_file())

    def test_wrong_sha_and_unexpected_path_are_rejected(self):
        with self.assertRaisesRegex(ValueError, "does not match"):
            sync.import_tokens(self.source, self.root / "Generated", "0" * 40)
        self.put("generated/ios/run.sh", "echo unsafe\n")
        with self.assertRaisesRegex(ValueError, "Unexpected generated path"):
            sync.import_tokens(self.source, self.root / "Generated", self.sha)

    def test_symlink_is_rejected(self):
        (self.source / "generated/ios/Sources/extra.swift").symlink_to("FestiCoreSemanticColor.swift")
        with self.assertRaisesRegex(ValueError, "ordinary, unlinked file"):
            sync.import_tokens(self.source, self.root / "Generated", self.sha)

    def test_asset_catalog_is_rejected(self):
        self.put("generated/ios/Assets/FestiCoreColors.xcassets/Contents.json", "{}\n")
        with self.assertRaisesRegex(ValueError, "Unexpected generated path"):
            sync.import_tokens(self.source, self.root / "Generated", self.sha)

    def test_changed_snapshot_is_rejected(self):
        destination = self.root / "Generated"
        sync.import_tokens(self.source, destination, self.sha)
        (destination / sync.TOKEN_PATH / "$themes.json").write_text("{\"changed\":true}\n")
        self.assertNotEqual(sync.snapshot_digest(destination, self.sha), sync.snapshot_digest(self._fresh_snapshot(), self.sha))

    def test_unrelated_sources_and_resources_are_preserved(self):
        destination = self.root / "FestiCoreDesignKit"
        (destination / "Sources/Component/Button").mkdir(parents=True)
        (destination / "Sources/Component/Button/FestiCorePrimaryButton.swift").write_text("import SwiftUI\n")
        (destination / "Sources/Token/Typography").mkdir(parents=True)
        (destination / "Sources/Token/Typography/Text+FestiCoreTextStyle.swift").write_text("import SwiftUI\n")
        (destination / "Resources/ImageAssets.xcassets").mkdir(parents=True)
        (destination / "Resources/ImageAssets.xcassets/Contents.json").write_text("{}\n")
        sync.import_tokens(self.source, destination, self.sha)
        self.assertEqual((destination / "Sources/Component/Button/FestiCorePrimaryButton.swift").read_text(), "import SwiftUI\n")
        self.assertEqual((destination / "Sources/Token/Typography/Text+FestiCoreTextStyle.swift").read_text(), "import SwiftUI\n")
        self.assertEqual((destination / "Resources/ImageAssets.xcassets/Contents.json").read_text(), "{}\n")

    def test_retired_generated_color_files_are_removed(self):
        destination = self.root / "FestiCoreDesignKit"
        for relative in sync.RETIRED_SOURCE_PATHS:
            target = destination / relative
            target.parent.mkdir(parents=True, exist_ok=True)
            target.write_text(sync.generated_header(target.name) + "import SwiftUI\n")
        sync.import_tokens(self.source, destination, self.sha)
        self.assertTrue(all(not (destination / relative).exists() for relative in sync.RETIRED_SOURCE_PATHS))

    def test_hand_written_retired_color_file_is_preserved(self):
        destination = self.root / "FestiCoreDesignKit"
        target = destination / sync.RETIRED_SOURCE_PATHS[0]
        target.parent.mkdir(parents=True, exist_ok=True)
        target.write_text("// 직접 작성한 파일\n")
        with self.assertRaisesRegex(ValueError, "Refusing to remove"):
            sync.import_tokens(self.source, destination, self.sha)
        self.assertEqual(target.read_text(), "// 직접 작성한 파일\n")

    def test_hand_written_file_at_generated_path_is_not_overwritten(self):
        destination = self.root / "FestiCoreDesignKit"
        path = destination / sync.SOURCE_PATHS["FestiCoreSemanticColor.swift"]
        path.parent.mkdir(parents=True)
        path.write_text("// 수동 색상 파일\nimport SwiftUI\n")
        with self.assertRaisesRegex(ValueError, "Refusing to overwrite"):
            sync.import_tokens(self.source, destination, self.sha)
        self.assertEqual(path.read_text(), "// 수동 색상 파일\nimport SwiftUI\n")
        self.assertFalse((destination / sync.SHA_PATH).exists())

    def test_reserved_generated_basename_cannot_exist_elsewhere(self):
        destination = self.root / "FestiCoreDesignKit"
        path = destination / "Sources/Component/FestiCoreSemanticColor.swift"
        path.parent.mkdir(parents=True)
        path.write_text("// 수동 색상 파일\n")
        with self.assertRaisesRegex(ValueError, "basename is reserved"):
            sync.import_tokens(self.source, destination, self.sha)
        self.assertEqual(path.read_text(), "// 수동 색상 파일\n")
        self.assertFalse((destination / sync.SHA_PATH).exists())

    def _fresh_snapshot(self):
        destination = self.root / "Fresh"
        sync.import_tokens(self.source, destination, self.sha)
        return destination


if __name__ == "__main__":
    unittest.main()
