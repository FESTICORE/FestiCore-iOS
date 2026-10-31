import os
import subprocess
import tempfile
import unittest
from pathlib import Path


SCRIPT = Path(__file__).with_name("warm-ci-module-cache.sh")
QUOTA_MESSAGE = (
    "The account 'festicore' has reached the limits of the plan 'Tuist Air' "
    "and requires upgrading to the plan 'Tuist Pro'."
)


class WarmCIModuleCacheTests(unittest.TestCase):
    def run_warm(self, remote_exit, remote_output, local_exit=0):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            mise = root / "mise"
            calls = root / "calls.txt"
            mise.write_text(
                "#!/usr/bin/env python3\n"
                "import os, sys\n"
                "from pathlib import Path\n"
                "args = sys.argv[1:]\n"
                "with Path(os.environ['MOCK_CALLS']).open('a') as output:\n"
                "    output.write(' '.join(args) + '\\n')\n"
                "local = '--no-upload' in args\n"
                "print(os.environ['MOCK_LOCAL_OUTPUT' if local else 'MOCK_REMOTE_OUTPUT'])\n"
                "sys.exit(int(os.environ['MOCK_LOCAL_EXIT' if local else 'MOCK_REMOTE_EXIT']))\n"
            )
            mise.chmod(0o755)
            environment = os.environ.copy()
            environment.update(
                PATH=f"{root}:{environment['PATH']}",
                TMPDIR=str(root),
                MOCK_CALLS=str(calls),
                MOCK_REMOTE_EXIT=str(remote_exit),
                MOCK_REMOTE_OUTPUT=remote_output,
                MOCK_LOCAL_EXIT=str(local_exit),
                MOCK_LOCAL_OUTPUT="local cache ready",
            )
            result = subprocess.run(
                ["bash", str(SCRIPT)],
                capture_output=True,
                text=True,
                env=environment,
                check=False,
            )
            return result, calls.read_text().splitlines() if calls.exists() else []

    def test_remote_success_does_not_retry(self):
        result, calls = self.run_warm(0, "remote cache ready")
        self.assertEqual(result.returncode, 0)
        self.assertEqual(len(calls), 1)
        self.assertNotIn("--no-upload", calls[0])

    def test_quota_failure_retries_with_local_cache(self):
        result, calls = self.run_warm(1, QUOTA_MESSAGE)
        self.assertEqual(result.returncode, 0)
        self.assertEqual(len(calls), 2)
        self.assertIn("--no-upload", calls[1])
        self.assertIn("::warning::", result.stdout)

    def test_other_failure_stays_failed(self):
        result, calls = self.run_warm(1, "Compilation failed")
        self.assertNotEqual(result.returncode, 0)
        self.assertEqual(len(calls), 1)

    def test_local_retry_failure_stays_failed(self):
        result, calls = self.run_warm(1, QUOTA_MESSAGE, local_exit=1)
        self.assertNotEqual(result.returncode, 0)
        self.assertEqual(len(calls), 2)


if __name__ == "__main__":
    unittest.main()
