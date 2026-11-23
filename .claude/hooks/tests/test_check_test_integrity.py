import os
import shutil
import subprocess
import tempfile
import unittest

SCRIPT = os.path.join(os.path.dirname(__file__), "..", "..", "scripts", "check-test-integrity")


class CheckTestIntegrityTests(unittest.TestCase):
    def setUp(self):
        self.root = tempfile.mkdtemp()
        subprocess.run(["git", "init", "-q", self.root], check=True, stdin=subprocess.DEVNULL)
        os.makedirs(os.path.join(self.root, ".claude", "scripts"))
        shutil.copy(SCRIPT, os.path.join(self.root, ".claude", "scripts", "check-test-integrity"))

    def tearDown(self):
        shutil.rmtree(self.root)

    def run_with(self, source, path="Projects/Feature/Home/Tests/Sources/HomeTests.swift"):
        full = os.path.join(self.root, path)
        os.makedirs(os.path.dirname(full), exist_ok=True)
        with open(full, "w", encoding="utf-8") as f:
            f.write(source)
        return subprocess.run(["python3", os.path.join(self.root, ".claude", "scripts", "check-test-integrity")],
                              capture_output=True, text=True, stdin=subprocess.DEVNULL)

    def test_blocks_disabled_test_without_issue(self):
        result = self.run_with('@Test(\n  "홈",\n  .disabled("나중에")\n)\nfunc home() {}\n')
        self.assertEqual(result.returncode, 1)
        self.assertIn("HomeTests.swift:3", result.stderr)

    def test_blocks_unconditional_skip(self):
        self.assertEqual(self.run_with('func test() throws { throw XCTSkip("x") }\n').returncode, 1)
        self.assertEqual(self.run_with("@Test(.enabled(if: false)) func a() {}\n").returncode, 1)

    def test_allows_issue_reference_on_same_or_previous_line(self):
        self.assertEqual(self.run_with('@Test(.disabled("서버 대기 #648")) func a() {}\n').returncode, 0)
        self.assertEqual(self.run_with('// 서버 대기 #648\n@Test(.disabled()) func a() {}\n').returncode, 0)

    def test_ignores_view_modifier_conditional_skip_and_strings(self):
        source = (
            'func v() { Button("저장") {}.disabled(false) }\n'
            '@Suite(.serialized) struct S { func c() { Text("").disabled(true) } }\n'
            "func t() throws { try XCTSkipIf(true) }\n"
            '// @Test(.disabled()) 설명\n'
        )
        self.assertEqual(self.run_with(source).returncode, 0)

    def test_allows_skips_under_conditions(self):
        source = (
            "func a() throws {\n"
            "  #if targetEnvironment(simulator)\n"
            '  throw XCTSkip("실기기에서만")\n'
            "  #endif\n"
            "  guard ready else {\n"
            '    throw XCTSkip("준비 안 됨")\n'
            "  }\n"
            "}\n"
            "#if targetEnvironment(simulator)\n"
            '@Suite("통합", .disabled("실기기에서 검증"))\n'
            "#endif\n"
            "struct S {}\n"
        )
        self.assertEqual(self.run_with(source).returncode, 0)

    def test_blocks_skip_at_function_top_level(self):
        result = self.run_with('func a() throws {\n  if x { print(1) }\n  throw XCTSkip("나중에")\n}\n')
        self.assertEqual(result.returncode, 1)
        self.assertIn("HomeTests.swift:3", result.stderr)

    def test_condition_edge_cases(self):
        multi_line_if = 'func a() throws {\n  if a,\n     b {\n    throw XCTSkip("x")\n  }\n}\n'
        self.assertEqual(self.run_with(multi_line_if).returncode, 0)
        label = 'func a() throws {\n  withFixture(for: account) {\n    throw XCTSkip("x")\n  }\n}\n'
        self.assertEqual(self.run_with(label).returncode, 1)
        simulator_only = "#if targetEnvironment(simulator)\n@Test(.enabled(if: false)) func a() {}\n#endif\n"
        self.assertEqual(self.run_with(simulator_only).returncode, 0)

    def test_ignores_non_test_sources(self):
        self.assertEqual(self.run_with('throw XCTSkip("x")\n', "Projects/Feature/Home/Sources/Home.swift").returncode, 0)


if __name__ == "__main__":
    unittest.main()
