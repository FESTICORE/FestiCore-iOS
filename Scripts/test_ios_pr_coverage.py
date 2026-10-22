import importlib.util
import unittest
from pathlib import Path


script = Path(__file__).with_name("ios-pr-coverage.py")
spec = importlib.util.spec_from_file_location("ios_pr_coverage", script)
report = importlib.util.module_from_spec(spec)
spec.loader.exec_module(report)


class CoverageReportTests(unittest.TestCase):
    def test_external_packages_and_test_bundles_are_excluded(self):
        targets = [
            {"name": "FestiCoreLogger.framework", "coveredLines": 7, "executableLines": 10},
            {"name": "Alamofire.framework", "coveredLines": 99, "executableLines": 100},
            {"name": "FestiCoreLoggerTests.xctest", "coveredLines": 10, "executableLines": 10},
        ]
        self.assertEqual(report.coverage_lines(targets, {"FestiCoreLogger"}), [("FestiCoreLogger", 7, 10)])

    def test_report_includes_test_counts_and_internal_coverage(self):
        body = report.render(
            {"passedTests": 8, "failedTests": 1, "skippedTests": 2, "totalTestCount": 11,
             "testFailures": [{"testIdentifierString": "StorageTests/testRead", "failureText": "value mismatch"}]},
            [("FestiCoreStorage", 5, 10)],
            "failure",
            "https://tuist.dev/suhwj81/festicore/tests/test-runs/id",
        )
        self.assertIn("8 passed · 1 failed · 2 skipped · 총 11개", body)
        self.assertIn("StorageTests/testRead", body)
        self.assertIn("자체 코드 커버리지 50.0%", body)
        self.assertIn("[Tuist 테스트 실행]", body)


if __name__ == "__main__":
    unittest.main()
