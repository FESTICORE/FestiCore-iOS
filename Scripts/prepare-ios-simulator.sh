#!/usr/bin/env bash

set -euo pipefail

readonly destination="${SIMULATOR_DESTINATION:?SIMULATOR_DESTINATION is required}"
readonly simulator_udid="${destination##*,id=}"

if [[ -z "$simulator_udid" || "$simulator_udid" == "$destination" ]]; then
  echo "시뮬레이터 destination에서 UDID를 찾을 수 없습니다: $destination" >&2
  exit 1
fi

simulator_state="$(xcrun simctl list devices available -j | python3 -c '
import json
import sys

devices = json.load(sys.stdin)["devices"]
print(next((device["state"] for runtime in devices.values() for device in runtime if device.get("udid") == sys.argv[1]), ""))
' "$simulator_udid")"

case "$simulator_state" in
  Booted)
    ;;
  Shutdown)
    xcrun simctl boot "$simulator_udid"
    if [[ -n "${GITHUB_ENV:-}" ]]; then
      echo "SIMULATOR_BOOTED_BY_JOB=$simulator_udid" >> "$GITHUB_ENV"
    fi
    ;;
  *)
    echo "iPhone Duo 상태를 확인할 수 없습니다: $simulator_udid ($simulator_state)" >&2
    exit 1
    ;;
esac
xcrun simctl bootstatus "$simulator_udid" -b
xcrun simctl spawn "$simulator_udid" /usr/bin/true

echo "CI 시뮬레이터 준비 완료: $simulator_udid"
