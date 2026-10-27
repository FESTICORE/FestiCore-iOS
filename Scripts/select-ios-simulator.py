#!/usr/bin/env python3

"""Print the newest available iOS runtime's iPhone Duo destination."""

import argparse
import json
import subprocess
import sys


DUO_TYPE = "com.apple.CoreSimulator.SimDeviceType.iPhone-Duo"
CI_DUO_NAME = "FestiCore CI iPhone Duo"


def runtime_version(runtime: dict) -> tuple[int, ...]:
    try:
        return tuple(int(part) for part in runtime["version"].split("."))
    except (KeyError, AttributeError, ValueError):
        raise SystemExit(f"iOS 런타임 버전 형식이 올바르지 않습니다: {runtime.get('identifier', 'unknown')}")


def load_simulators() -> dict:
    if not sys.stdin.isatty():
        stdin = sys.stdin.read().strip()
        if stdin:
            return json.loads(stdin)

    return {
        kind: json.loads(subprocess.check_output(
            ["xcrun", "simctl", "list", kind, "available", "--json"], text=True,
        ))[kind]
        for kind in ("runtimes", "devices")
    }


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--ci-duo", action="store_true", help="Use the dedicated FestiCore CI Duo")
    args = parser.parse_args()
    simulators = load_simulators()
    ios_runtimes = [
        runtime for runtime in simulators.get("runtimes", [])
        if runtime.get("platform") == "iOS" and runtime.get("isAvailable")
    ]
    if not ios_runtimes:
        raise SystemExit("사용 가능한 iOS 시뮬레이터 런타임이 없습니다.")

    latest = max(ios_runtimes, key=runtime_version)
    available_duos = [
        device for device in simulators.get("devices", {}).get(latest["identifier"], [])
        if device.get("isAvailable", True)
        and device.get("deviceTypeIdentifier") == DUO_TYPE
        and device.get("udid")
    ]
    if not available_duos:
        raise SystemExit(f"최신 iOS 런타임({latest['identifier']})에 사용 가능한 iPhone Duo가 없습니다.")

    if args.ci_duo:
        available_duos = [device for device in available_duos if device.get("name") == CI_DUO_NAME]
        if len(available_duos) != 1:
            raise SystemExit(f"최신 iOS 런타임({latest['identifier']})에 CI 전용 iPhone Duo가 정확히 한 대 있어야 합니다: {CI_DUO_NAME}")
        if available_duos[0].get("state") not in ("Booted", "Shutdown"):
            raise SystemExit(f"CI 전용 iPhone Duo가 준비 중인 상태입니다: {available_duos[0].get('state')}")
    else:
        available_duos = [device for device in available_duos if device.get("name") != CI_DUO_NAME]
        if not available_duos:
            raise SystemExit(f"최신 iOS 런타임({latest['identifier']})에 개인 작업용 iPhone Duo가 없습니다.")

    preferred_state = "Booted"
    available_duos.sort(key=lambda device: (
        device.get("state") != preferred_state, device.get("name", ""), device["udid"],
    ))
    print(f"platform=iOS Simulator,id={available_duos[0]['udid']}")


if __name__ == "__main__":
    main()
