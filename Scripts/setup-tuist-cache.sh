#!/usr/bin/env bash

set -euo pipefail

: "${GITHUB_ENV:?GITHUB_ENV is required}"

error_log="$(mktemp "${RUNNER_TEMP:-${TMPDIR:-/tmp}}/festicore-tuist-cache.XXXXXX")"
config_output="$(mktemp "${RUNNER_TEMP:-${TMPDIR:-/tmp}}/festicore-tuist-config.XXXXXX")"
trap 'rm -f "$error_log" "$config_output"' EXIT

disable_cache() {
  echo "::warning::$1"
  echo 'XCODE_COMPILATION_CACHE_ENABLED=NO' >> "$GITHUB_ENV"
  if [[ -n "${GITHUB_OUTPUT:-}" ]]; then
    echo 'enabled=false' >> "$GITHUB_OUTPUT"
  fi
}

if [[ -z "${TUIST_TOKEN:-}" ]]; then
  disable_cache 'Tuist cache disabled: TUIST_TOKEN is missing.'
  exit 0
fi

# setup cache는 로컬 프록시 기동만 확인한다. 원격 캐시 토큰 발급을 먼저 검증한다.
# JSON 응답에는 인증 토큰이 포함되므로 CI 로그에 출력하지 않는다.
if mise exec -- tuist cache config FestiCore/festicore --json --force-refresh \
  > "$config_output" 2> "$error_log"; then
  :
else
  config_exit_code=$?
  if grep -Eiq 'has reached the limits of the plan|requires upgrading to the plan' "$error_log"; then
    disable_cache 'Tuist cache disabled: the FestiCore account reached its plan limit.'
  elif grep -Eiq 'permission|not authorized|unauthorized|not authenticated' "$error_log"; then
    disable_cache 'Tuist cache disabled: TUIST_TOKEN cannot access FestiCore/festicore.'
  elif grep -Eiq 'timed out|could not connect|connection refused|network is unreachable|temporarily unavailable|HTTP 5[0-9][0-9]' "$error_log"; then
    disable_cache 'Tuist cache disabled: the remote cache service is unavailable.'
  else
    disable_cache 'Tuist cache disabled: token request failed unexpectedly.'
    echo "::error::Tuist cache token request failed unexpectedly (exit $config_exit_code); inspect the runner without exposing credentials."
    exit "$config_exit_code"
  fi
  exit 0
fi

if ! python3 -c '
import json
import sys

response = sys.stdin.read()
start = response.find("{")
try:
    data = json.JSONDecoder().raw_decode(response[start:])[0] if start >= 0 else {}
except (ValueError, TypeError):
    data = {}
sys.exit(not isinstance(data, dict) or not isinstance(data.get("token"), str) or not data["token"])
' < "$config_output"; then
  disable_cache 'Tuist cache disabled: token response was invalid.'
  echo '::error::Tuist cache config returned invalid token JSON.'
  exit 1
fi

if ! mise exec -- tuist setup cache > /dev/null 2> "$error_log"; then
  disable_cache 'Tuist cache disabled: the cache proxy could not start.'
  echo '::error::Tuist cache proxy could not start; inspect the runner without exposing credentials.'
  exit 1
fi

echo 'XCODE_COMPILATION_CACHE_ENABLED=YES' >> "$GITHUB_ENV"
if [[ -n "${GITHUB_OUTPUT:-}" ]]; then
  echo 'enabled=true' >> "$GITHUB_OUTPUT"
fi
echo 'Tuist remote cache token and proxy setup verified.'
