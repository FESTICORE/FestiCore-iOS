import importlib.machinery
import importlib.util
import pathlib
import tempfile
import unittest


SCRIPT = pathlib.Path(__file__).resolve().parents[2] / "scripts" / "file-header"
loader = importlib.machinery.SourceFileLoader("file_header", str(SCRIPT))
spec = importlib.util.spec_from_loader("file_header", loader)
module = importlib.util.module_from_spec(spec)
loader.exec_module(module)


def header(name, module_name, date="11/20/26", author="FestiCore"):
    return f"//\n//  {name}\n//  {module_name}\n//\n//  Created by {author} on {date}.\n//\n\nimport Foundation\n"


class FileHeaderTests(unittest.TestCase):
    def test_module_name_follows_target_folder(self):
        cases = {
            "Projects/Feature/Festival/Sources/LiveBoard/View/A.swift": "Festival",
            "Projects/Feature/Festival/Tests/Sources/ATests.swift": "FestivalTests",
            "Projects/Domain/FestivalDomain/Interface/Sources/Entity/A.swift": "FestivalDomainInterface",
            "Projects/UI/FestiCoreDesignKit/Demo/Sources/A.swift": "FestiCoreDesignKitDemo",
            "Projects/Service/FestiCoreDevice/Project.swift": "FestiCoreDevice",
            "Projects/App/Sources/Navigation/A.swift": "FestiCore",
            "Projects/App/Tests/Sources/ATests.swift": "FestiCoreTests",
            "Projects/App/Tests/UITests/AUITests.swift": "FestiCoreUITests",
            "Plugins/DependencyPlugin/ProjectDescriptionHelpers/A.swift": "FestiCore",
        }
        for path, expected in cases.items():
            with self.subTest(path=path):
                self.assertEqual(expected, module.module_names(path)[0])

    def test_valid_header_passes(self):
        path = "Projects/Feature/Festival/Sources/A.swift"
        self.assertIsNone(module.problem(path, header("A.swift", "Festival")))

    def test_wrong_or_missing_header_is_reported(self):
        path = "Projects/Feature/Festival/Sources/A.swift"
        self.assertIn("헤더", module.problem(path, "import Foundation\n"))
        self.assertIn("모듈", module.problem(path, header("A.swift", "FestivalTests")))
        self.assertIn("파일 이름", module.problem(path, header("B.swift", "Festival")))
        self.assertIn("작성자", module.problem(path, header("A.swift", "Festival", author="Roy")))
        self.assertIn("날짜", module.problem(path, header("A.swift", "Festival", date="13/40/26")))

    def test_base_mode_checks_only_added_and_untracked_files(self):
        calls = []

        def fake_git_lines(*args):
            calls.append(args)
            if args[0] == "diff":
                return ["Projects/Feature/Festival/Sources/New.swift"]
            return ["Projects/Feature/Festival/Sources/Draft.swift"]

        original = module.git_lines
        module.git_lines = fake_git_lines
        try:
            files = module.added_files("BASE")
        finally:
            module.git_lines = original
        self.assertEqual(
            ["Projects/Feature/Festival/Sources/Draft.swift", "Projects/Feature/Festival/Sources/New.swift"],
            files,
        )
        self.assertEqual(("diff", "--name-only", "--diff-filter=A", "BASE", "--", "*.swift"), calls[0])

    def test_fix_adds_header_and_keeps_body(self):
        with tempfile.TemporaryDirectory() as directory:
            path = pathlib.Path(directory) / "Sample.swift"
            path.write_text("//  Sample.swift\n//  Created by Someone on 1/2/26.\n\nimport Foundation\nlet value = 1\n")
            self.assertEqual(1, module.main([str(path)]))
            self.assertEqual(0, module.main(["--fix", str(path)]))
            text = path.read_text()
            self.assertTrue(text.startswith("//\n//  Sample.swift\n//  FestiCore\n//\n//  Created by FestiCore on "))
            self.assertTrue(text.endswith("import Foundation\nlet value = 1\n"))
            self.assertEqual(0, module.main([str(path)]))


if __name__ == "__main__":
    unittest.main()
