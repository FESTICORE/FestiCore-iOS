#!/usr/bin/env python3

"""Check that CI does not accept a failed simulator data migration."""

import os
import pathlib
import subprocess
import tempfile
import unittest


SCRIPT = pathlib.Path(__file__).with_name("prepare-ios-simulator.sh")


class PrepareIOSSimulatorTests(unittest.TestCase):
    def run_prepare(self, failed_boots: int) -> tuple[subprocess.CompletedProcess[str], list[str]]:
        with tempfile.TemporaryDirectory() as directory:
            root = pathlib.Path(directory)
            executable = root / "xcrun"
            calls = root / "calls"
            boots = root / "boots"
            executable.write_text(
                "#!/bin/sh\n"
                "echo \"$*\" >> \"$CALLS\"\n"
                "if [ \"$1 $2\" = 'simctl bootstatus' ]; then\n"
                "  count=$(cat \"$BOOTS\" 2>/dev/null || echo 0)\n"
                "  count=$((count + 1))\n"
                "  echo \"$count\" > \"$BOOTS\"\n"
                "  if [ \"$count\" -le \"$FAILED_BOOTS\" ]; then\n"
                "    echo 'Data Migration Failed'\n"
                "  else\n"
                "    echo 'Booted'\n"
                "  fi\n"
                "fi\n"
            )
            executable.chmod(0o755)
            environment = os.environ | {
                "PATH": f"{root}:{os.environ['PATH']}",
                "SIMULATOR_DESTINATION": "platform=iOS Simulator,id=DUO",
                "CALLS": str(calls),
                "BOOTS": str(boots),
                "FAILED_BOOTS": str(failed_boots),
            }
            result = subprocess.run([str(SCRIPT)], env=environment, capture_output=True, text=True)
            return result, calls.read_text().splitlines()

    def test_recovers_after_one_failed_migration(self) -> None:
        result, calls = self.run_prepare(failed_boots=1)

        self.assertEqual(result.returncode, 0, result.stdout + result.stderr)
        self.assertEqual(calls.count("simctl bootstatus DUO -b"), 2)
        self.assertIn("simctl shutdown DUO", calls)
        self.assertIn("CI 시뮬레이터 준비 완료", result.stdout)

    def test_stops_after_repeated_failed_migration(self) -> None:
        result, calls = self.run_prepare(failed_boots=2)

        self.assertNotEqual(result.returncode, 0)
        self.assertEqual(calls.count("simctl bootstatus DUO -b"), 2)
        self.assertNotIn("simctl spawn DUO /usr/bin/true", calls)
        self.assertNotIn("CI 시뮬레이터 준비 완료", result.stdout)


if __name__ == "__main__":
    unittest.main()
