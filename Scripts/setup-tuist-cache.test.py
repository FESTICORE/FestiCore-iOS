import os
from pathlib import Path
import subprocess
import tempfile
import unittest


SCRIPT = Path(__file__).with_name("setup-tuist-cache.sh")


class SetupTuistCacheTests(unittest.TestCase):
    def run_case(
        self, scenario: str, token: str = "test-token", expected_exit: int = 0
    ) -> tuple[str, str, str, str]:
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            fake_mise = root / "mise"
            fake_mise.write_text(
                "#!/usr/bin/env bash\n"
                "echo \"$*\" >> \"$CALL_LOG\"\n"
                "if [[ \"$SCENARIO\" == plan-limit && \"$4 $5\" == 'cache config' ]]; then\n"
                "  echo \"The account 'FestiCore' has reached the limits of the plan 'Tuist Air' and requires upgrading to the plan 'Tuist Pro'.\" >&2\n"
                "  exit 1\n"
                "fi\n"
                "if [[ \"$SCENARIO\" == no-permission && \"$4 $5\" == 'cache config' ]]; then\n"
                "  echo 'You do not have permission.' >&2\n"
                "  exit 1\n"
                "fi\n"
                "if [[ \"$SCENARIO\" == network-failure && \"$4 $5\" == 'cache config' ]]; then\n"
                "  echo 'connection refused' >&2\n"
                "  exit 1\n"
                "fi\n"
                "if [[ \"$SCENARIO\" == unknown-failure && \"$4 $5\" == 'cache config' ]]; then\n"
                "  echo 'secret: unexpected process error' >&2\n"
                "  exit 7\n"
                "fi\n"
                "if [[ \"$SCENARIO\" == setup-failure && \"$4 $5\" == 'setup cache' ]]; then\n"
                "  echo 'secret: proxy failed' >&2\n"
                "  exit 1\n"
                "fi\n"
                "if [[ \"$SCENARIO\" == empty-token && \"$4 $5\" == 'cache config' ]]; then echo '{\"token\":\"\"}'; exit 0; fi\n"
                "if [[ \"$SCENARIO\" == malformed-json && \"$4 $5\" == 'cache config' ]]; then echo 'secret: <'; exit 0; fi\n"
                "if [[ \"$4 $5\" == 'cache config' ]]; then echo '{\"token\":\"secret\"}'; fi\n"
            )
            fake_mise.chmod(0o755)
            github_env = root / "github-env"
            github_output = root / "github-output"
            call_log = root / "calls"
            environment = os.environ | {
                "PATH": f"{root}:{os.environ['PATH']}",
                "GITHUB_ENV": str(github_env),
                "GITHUB_OUTPUT": str(github_output),
                "RUNNER_TEMP": str(root),
                "TUIST_TOKEN": token,
                "CALL_LOG": str(call_log),
                "SCENARIO": scenario,
            }
            result = subprocess.run(
                ["bash", str(SCRIPT)],
                env=environment,
                capture_output=True,
                text=True,
                check=False,
            )
            self.assertEqual(result.returncode, expected_exit, result.stderr)
            self.assertNotIn("secret", result.stdout + result.stderr)
            return (
                result.stdout,
                github_env.read_text() if github_env.exists() else "",
                github_output.read_text() if github_output.exists() else "",
                call_log.read_text() if call_log.exists() else "",
            )

    def test_verified_cache_is_enabled(self):
        output, github_env, github_output, calls = self.run_case("success")
        self.assertIn("verified", output)
        self.assertEqual(github_env, "XCODE_COMPILATION_CACHE_ENABLED=YES\n")
        self.assertEqual(github_output, "enabled=true\n")
        self.assertIn("cache config FestiCore/festicore --json --force-refresh", calls)
        self.assertIn("setup cache", calls)

    def test_plan_limit_disables_cache_before_proxy_setup(self):
        output, github_env, github_output, calls = self.run_case("plan-limit")
        self.assertIn("plan limit", output)
        self.assertEqual(github_env, "XCODE_COMPILATION_CACHE_ENABLED=NO\n")
        self.assertEqual(github_output, "enabled=false\n")
        self.assertNotIn("setup cache", calls)

    def test_permission_error_disables_cache(self):
        output, github_env, github_output, calls = self.run_case("no-permission")
        self.assertIn("cannot access", output)
        self.assertEqual(github_env, "XCODE_COMPILATION_CACHE_ENABLED=NO\n")
        self.assertEqual(github_output, "enabled=false\n")
        self.assertNotIn("setup cache", calls)

    def test_network_failure_disables_cache(self):
        output, github_env, github_output, calls = self.run_case("network-failure")
        self.assertIn("service is unavailable", output)
        self.assertEqual(github_env, "XCODE_COMPILATION_CACHE_ENABLED=NO\n")
        self.assertEqual(github_output, "enabled=false\n")
        self.assertNotIn("setup cache", calls)

    def test_proxy_failure_fails_with_sanitized_diagnostic(self):
        output, github_env, github_output, calls = self.run_case("setup-failure", expected_exit=1)
        self.assertIn("proxy could not start", output)
        self.assertEqual(github_env, "XCODE_COMPILATION_CACHE_ENABLED=NO\n")
        self.assertEqual(github_output, "enabled=false\n")
        self.assertIn("setup cache", calls)

    def test_empty_cache_token_fails(self):
        output, github_env, github_output, calls = self.run_case("empty-token", expected_exit=1)
        self.assertIn("invalid token JSON", output)
        self.assertEqual(github_env, "XCODE_COMPILATION_CACHE_ENABLED=NO\n")
        self.assertEqual(github_output, "enabled=false\n")
        self.assertNotIn("setup cache", calls)

    def test_malformed_json_fails(self):
        output, github_env, github_output, calls = self.run_case("malformed-json", expected_exit=1)
        self.assertIn("invalid token JSON", output)
        self.assertEqual(github_env, "XCODE_COMPILATION_CACHE_ENABLED=NO\n")
        self.assertEqual(github_output, "enabled=false\n")
        self.assertNotIn("setup cache", calls)

    def test_unknown_failure_preserves_exit_status(self):
        output, github_env, github_output, calls = self.run_case("unknown-failure", expected_exit=7)
        self.assertIn("failed unexpectedly (exit 7)", output)
        self.assertEqual(github_env, "XCODE_COMPILATION_CACHE_ENABLED=NO\n")
        self.assertEqual(github_output, "enabled=false\n")
        self.assertNotIn("setup cache", calls)

    def test_missing_token_disables_cache_without_calling_tuist(self):
        output, github_env, github_output, calls = self.run_case("success", token="")
        self.assertIn("TUIST_TOKEN is missing", output)
        self.assertEqual(github_env, "XCODE_COMPILATION_CACHE_ENABLED=NO\n")
        self.assertEqual(github_output, "enabled=false\n")
        self.assertEqual(calls, "")


if __name__ == "__main__":
    unittest.main()
