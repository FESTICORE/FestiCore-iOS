#!/usr/bin/env bash
set -euo pipefail

# Run on the Mac where the FestiCore GitHub runner is already registered.
runner_root="${1:?사용법: $0 <FestiCore runner 설치 경로>}"
cd "$runner_root"

if [[ ! -f .runner || ! -x svc.sh ]]; then
  echo "등록된 GitHub runner의 설치 경로가 아닙니다: $runner_root" >&2
  exit 1
fi
if ! grep -q 'FESTICORE-FestiCore-iOS' svc.sh; then
  echo "FestiCore-iOS 전용 runner가 아닙니다: $runner_root" >&2
  exit 1
fi

if [[ ! -f .service ]]; then
  ./svc.sh install
fi

service_plist="$(cat .service)"
if [[ ! -f "$service_plist" ]]; then
  echo "runner LaunchAgent가 없습니다: $service_plist" >&2
  exit 1
fi

if [[ "$(/usr/libexec/PlistBuddy -c 'Print :RunAtLoad' "$service_plist")" != "true" ]]; then
  echo "runner LaunchAgent의 RunAtLoad가 활성화되지 않았습니다." >&2
  exit 1
fi

service_label="$(/usr/libexec/PlistBuddy -c 'Print :Label' "$service_plist")"
if ! launchctl print "gui/$(id -u)/$service_label" >/dev/null 2>&1; then
  ./svc.sh start
fi
./svc.sh status
