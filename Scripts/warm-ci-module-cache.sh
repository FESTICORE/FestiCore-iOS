#!/usr/bin/env bash
set -euo pipefail

log_file="$(mktemp "${TMPDIR:-/tmp}/festicore-tuist-warm.XXXXXX")"
trap 'rm -f "$log_file"' EXIT

if mise exec -- tuist cache warm --cache-profile only-external --configuration Stage 2>&1 | tee "$log_file"; then
  exit 0
fi

quota_message="The account 'festicore' has reached the limits of the plan 'Tuist Air' and requires upgrading to the plan 'Tuist Pro'."
if ! grep -Fq "$quota_message" "$log_file"; then
  exit 1
fi

echo '::warning::Tuist 원격 캐시 한도 초과로 업로드에 실패했습니다. 로컬 모듈 캐시를 다시 생성합니다.'
mise exec -- tuist cache warm --cache-profile only-external --configuration Stage --no-upload
