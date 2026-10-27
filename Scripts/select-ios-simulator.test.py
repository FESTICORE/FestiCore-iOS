#!/usr/bin/env python3

"""Regression tests for the local and CI simulator destination."""

import json
import os
from pathlib import Path
import subprocess
import sys
import tempfile
import unittest


SCRIPT = Path(__file__).with_name("select-ios-simulator.py")
PREPARE_SCRIPT = Path(__file__).with_name("prepare-ios-simulator.sh")
DUO_TYPE = "com.apple.CoreSimulator.SimDeviceType.iPhone-Duo"


def runtime(version: str, platform: str = "iOS", available: bool = True) -> dict:
    return {
        "identifier": f"com.apple.CoreSimulator.SimRuntime.{platform}-{version.replace('.', '-')}",
        "version": version,
        "platform": platform,
        "isAvailable": available,
    }


def device(name: str, udid: str, device_type: str = DUO_TYPE,
           state: str = "Shutdown", available: bool = True) -> dict:
    return {
        "name": name,
        "udid": udid,
        "deviceTypeIdentifier": device_type,
        "state": state,
        "isAvailable": available,
    }


class SimulatorSelectionTests(unittest.TestCase):
    def run_selector(self, runtimes: list[dict], devices: dict,
                     *args: str) -> subprocess.CompletedProcess[str]:
        return subprocess.run(
            [sys.executable, str(SCRIPT), *args],
            input=json.dumps({"runtimes": runtimes, "devices": devices}),
            text=True,
            capture_output=True,
            check=False,
        )

    def test_selects_booted_duo_on_newest_available_ios_runtime(self) -> None:
        old = runtime("9.3")
        latest = runtime("18.4")
        unavailable = runtime("27.1", available=False)
        watch = runtime("28.0", platform="watchOS")
        result = self.run_selector([old, latest, unavailable, watch], {
            old["identifier"]: [device("iPhone Duo", "older")],
            latest["identifier"]: [
                device("iPhone Duo", "wrong-type", "com.apple.CoreSimulator.SimDeviceType.iPhone-17"),
                device("iPhone Duo Plus", "wrong-name", "com.apple.CoreSimulator.SimDeviceType.iPhone-17"),
                device("iPhone Duo", "unavailable", available=False),
                device("iPhone Duo", "booted", state="Booted"),
                device("iPhone Duo (CI)", "shutdown"),
            ],
            unavailable["identifier"]: [device("iPhone Duo", "unavailable-runtime")],
            watch["identifier"]: [device("iPhone Duo", "watch")],
        })
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual(result.stdout.strip(), "platform=iOS Simulator,id=booted")

        ci = self.run_selector([old, latest, unavailable, watch], {
            latest["identifier"]: [
                device("iPhone Duo", "booted", state="Booted"),
                device("iPhone Duo (CI)", "shutdown"),
            ],
        }, "--require-shutdown")
        self.assertEqual(ci.returncode, 0, ci.stderr)
        self.assertEqual(ci.stdout.strip(), "platform=iOS Simulator,id=shutdown")

    def test_deterministic_tie_break_between_shutdown_duos(self) -> None:
        latest = runtime("27.1")
        result = self.run_selector([latest], {
            latest["identifier"]: [
                device("iPhone Duo (CI)", "z"),
                device("iPhone Duo (CI)", "a"),
                device("iPhone Duo", "b"),
            ],
        })
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual(result.stdout.strip(), "platform=iOS Simulator,id=b")

    def test_fails_instead_of_falling_back_to_older_runtime_or_other_iphone(self) -> None:
        old = runtime("27.0")
        latest = runtime("27.1")
        result = self.run_selector([old, latest], {
            old["identifier"]: [device("iPhone Duo", "older")],
            latest["identifier"]: [device("iPhone Duo", "other", "com.apple.CoreSimulator.SimDeviceType.iPhone-17")],
        })
        self.assertNotEqual(result.returncode, 0)
        self.assertIn("iPhone Duo가 없습니다", result.stderr)
        self.assertIn(latest["identifier"], result.stderr)

    def test_fails_if_newest_runtime_has_no_devices(self) -> None:
        old = runtime("27.0")
        latest = runtime("27.1")
        result = self.run_selector([old, latest], {
            old["identifier"]: [device("iPhone Duo", "older")],
            latest["identifier"]: [],
        })
        self.assertNotEqual(result.returncode, 0)
        self.assertIn(latest["identifier"], result.stderr)

    def test_fails_without_available_ios_runtime(self) -> None:
        result = self.run_selector([runtime("28.0", platform="watchOS")], {})
        self.assertNotEqual(result.returncode, 0)
        self.assertIn("사용 가능한 iOS 시뮬레이터 런타임이 없습니다", result.stderr)

    def test_ci_fails_instead_of_reusing_booted_duo(self) -> None:
        latest = runtime("27.1")
        devices = {latest["identifier"]: [device("iPhone Duo", "in-use", state="Booted")]}
        local = self.run_selector([latest], devices)
        ci = self.run_selector([latest], devices, "--require-shutdown")
        self.assertEqual(local.stdout.strip(), "platform=iOS Simulator,id=in-use")
        self.assertNotEqual(ci.returncode, 0)
        self.assertIn("종료된 iPhone Duo가 없습니다", ci.stderr)

    def test_fails_clearly_on_malformed_runtime_version(self) -> None:
        latest = runtime("27.1")
        latest["version"] = "beta"
        result = self.run_selector([latest], {})
        self.assertNotEqual(result.returncode, 0)
        self.assertIn("iOS 런타임 버전 형식이 올바르지 않습니다", result.stderr)
        self.assertNotIn("Traceback", result.stderr)


class SimulatorPreparationTests(unittest.TestCase):
    def run_prepare(self, boot_fails: bool) -> tuple[subprocess.CompletedProcess[str], str]:
        with tempfile.TemporaryDirectory() as directory:
            path = Path(directory)
            xcrun = path / "xcrun"
            xcrun.write_text(
                "#!/bin/sh\n"
                "if [ \"$2\" = boot ] && [ \"$MOCK_BOOT_FAIL\" = 1 ]; then exit 1; fi\n"
                "exit 0\n"
            )
            xcrun.chmod(0o755)
            github_env = path / "github-env"
            environment = os.environ.copy()
            environment.update({
                "PATH": f"{directory}:{environment['PATH']}",
                "SIMULATOR_DESTINATION": "platform=iOS Simulator,id=duo-id",
                "GITHUB_ENV": str(github_env),
                "MOCK_BOOT_FAIL": "1" if boot_fails else "0",
            })
            result = subprocess.run(
                ["bash", str(PREPARE_SCRIPT)], env=environment,
                text=True, capture_output=True, check=False,
            )
            return result, github_env.read_text() if github_env.exists() else ""

    def test_marks_successfully_booted_duo_as_owned(self) -> None:
        result, marker = self.run_prepare(boot_fails=False)
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual(marker, "SIMULATOR_BOOTED_BY_JOB=duo-id\n")

    def test_does_not_claim_duo_when_boot_fails(self) -> None:
        result, marker = self.run_prepare(boot_fails=True)
        self.assertNotEqual(result.returncode, 0)
        self.assertEqual(marker, "")


if __name__ == "__main__":
    unittest.main()
