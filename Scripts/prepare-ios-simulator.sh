#!/usr/bin/env bash

set -euo pipefail

readonly destination="${SIMULATOR_DESTINATION:?SIMULATOR_DESTINATION is required}"
readonly simulator_udid="${destination##*,id=}"

if [[ -z "$simulator_udid" || "$simulator_udid" == "$destination" ]]; then
  echo "시뮬레이터 destination에서 UDID를 찾을 수 없습니다: $destination" >&2
  exit 1
fi

xcrun simctl boot "$simulator_udid" 2>/dev/null || true
xcrun simctl bootstatus "$simulator_udid" -b
xcrun simctl spawn "$simulator_udid" /usr/bin/true

echo "CI 시뮬레이터 준비 완료: $simulator_udid"
