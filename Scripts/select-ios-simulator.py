#!/usr/bin/env python3

"""Print the newest available iOS runtime's iPhone Duo destination."""

import argparse
import json
import subprocess
import sys


DUO_TYPE = "com.apple.CoreSimulator.SimDeviceType.iPhone-Duo"


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
    parser.add_argument("--prefer-shutdown", action="store_true", help="Prefer an unused Duo for CI")
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

    if args.prefer_shutdown:
        shutdown_duos = [device for device in available_duos if device.get("state") == "Shutdown"]
        if shutdown_duos:
            available_duos = shutdown_duos
        else:
            # CI가 남긴 부팅 상태가 모두 남아 있으면 최근 사용한 Duo를 재사용한다.
            available_duos.sort(key=lambda device: (device.get("lastUsedAt", ""), device["udid"]), reverse=True)
            print(f"platform=iOS Simulator,id={available_duos[0]['udid']}")
            return

    preferred_state = "Shutdown" if args.prefer_shutdown else "Booted"
    available_duos.sort(key=lambda device: (
        device.get("state") != preferred_state, device.get("name", ""), device["udid"],
    ))
    print(f"platform=iOS Simulator,id={available_duos[0]['udid']}")


if __name__ == "__main__":
    main()
