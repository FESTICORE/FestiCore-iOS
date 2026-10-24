#!/usr/bin/env bash

set -euo pipefail

readonly destination="${SIMULATOR_DESTINATION:?SIMULATOR_DESTINATION is required}"
readonly simulator_udid="${destination##*,id=}"

if [[ -z "$simulator_udid" || "$simulator_udid" == "$destination" ]]; then
  echo "시뮬레이터 destination에서 UDID를 찾을 수 없습니다: $destination" >&2
  exit 1
fi

prepare_simulator() {
  local boot_output
  local boot_status=0

  xcrun simctl boot "$simulator_udid" 2>/dev/null || true
  boot_output="$(xcrun simctl bootstatus "$simulator_udid" -b 2>&1)" || boot_status=$?
  printf '%s\n' "$boot_output"

  # bootstatus가 0을 반환해도 데이터 마이그레이션 실패 후 앱을 실행하지 못할 수 있다.
  if (( boot_status != 0 )) || [[ "$boot_output" == *"Data Migration Failed"* ]]; then
    return 1
  fi

  xcrun simctl spawn "$simulator_udid" /usr/bin/true
}

if ! prepare_simulator; then
  echo "시뮬레이터 부팅을 다시 시도합니다: $simulator_udid" >&2
  xcrun simctl shutdown "$simulator_udid" >/dev/null 2>&1 || true
  if ! prepare_simulator; then
    echo "iPhone 시뮬레이터를 준비하지 못했습니다: $simulator_udid" >&2
    exit 1
  fi
fi

echo "CI 시뮬레이터 준비 완료: $simulator_udid"
