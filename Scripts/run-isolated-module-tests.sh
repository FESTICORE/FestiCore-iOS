#!/usr/bin/env bash

set -euo pipefail

readonly TEST_SCHEME="${TEST_SCHEME:-FestiCore-Stage}"
readonly TEST_PLAN="${TEST_PLAN:-FestiCore}"
readonly CONFIGURATION="${CONFIGURATION:-Stage}"
readonly SIMULATOR_DESTINATION="${SIMULATOR_DESTINATION:?SIMULATOR_DESTINATION is required}"
readonly CI_DERIVED_DATA="${CI_DERIVED_DATA:?CI_DERIVED_DATA is required}"
readonly RESULT_BUNDLE="${RESULT_BUNDLE:-TestResults.xcresult}"
readonly TEST_RUN_REPORT_PATH="${TEST_RUN_REPORT_PATH:-TestRunReport.json}"
readonly TEST_LOG_PATH="${TEST_LOG_PATH:-TuistTestRun.log}"

compilation_cache_enabled="${XCODE_COMPILATION_CACHE_ENABLED:-NO}"

rm -rf "$RESULT_BUNDLE" "$TEST_RUN_REPORT_PATH" "$TEST_LOG_PATH"

shard_arguments=()
if [[ -n "${TUIST_SHARD_PLAN_ID:-}" || -n "${TUIST_SHARD_INDEX:-}" ]]; then
  if [[ -z "${TUIST_SHARD_PLAN_ID:-}" || -z "${TUIST_SHARD_INDEX:-}" ]]; then
    echo "TUIST_SHARD_PLAN_ID와 TUIST_SHARD_INDEX는 함께 지정해야 합니다." >&2
    exit 1
  fi
  shard_arguments=(
    --without-building
    --shard-plan-id "$TUIST_SHARD_PLAN_ID"
    --shard-index "$TUIST_SHARD_INDEX"
  )
fi

# 모듈 테스트는 별도 host 없이 로직 테스트로 실행한다.
# 하나의 Stage workspace scheme으로 실행하면 SPM/TCA 그래프를 한 번만 빌드하면서도
# xcresult에 모듈별 테스트 케이스와 커버리지가 함께 기록된다.
#
# PR 리포트가 이전 커밋의 모듈 실행을 섞지 않도록 모든 테스트 타깃을 실행한다.
# run report는 Tuist 서버 업로드 여부와 최신 dashboard URL을 CI에서 검증하는 증거다.
run_tests() {
  mise exec -- tuist test run "$TEST_SCHEME" \
    --test-plan "$TEST_PLAN" \
    --configuration "$CONFIGURATION" \
    --no-selective-testing \
    --skip-quarantine \
    "${shard_arguments[@]}" \
    --inspect-mode remote \
    --result-bundle-path "$RESULT_BUNDLE" \
    --run-report-path "$TEST_RUN_REPORT_PATH" \
    --path "$PWD" \
    -- \
    -destination "$SIMULATOR_DESTINATION" \
    -derivedDataPath "$CI_DERIVED_DATA" \
    -enableCodeCoverage YES \
    SWIFT_ENABLE_PREFIX_MAPPING=NO \
    SWIFT_ENABLE_PROJECT_PREFIX_MAPPING=NO \
    CLANG_ENABLE_PREFIX_MAPPING=NO \
    CLANG_ENABLE_PROJECT_PREFIX_MAPPING=NO \
    -retry-tests-on-failure \
    -test-iterations 2 \
    -collect-test-diagnostics never \
    ONLY_ACTIVE_ARCH=YES \
    COMPILATION_CACHE_ENABLE_CACHING="$compilation_cache_enabled"
}

if run_tests 2>&1 | tee "$TEST_LOG_PATH"; then
  :
elif grep -Fq 'The test runner hung before establishing connection.' "$TEST_LOG_PATH" \
  || grep -Fq 'did not return a process handle nor launch error.' "$TEST_LOG_PATH"; then
  # XCTest 연결이나 테스트 호스트 앱 실행이 실패한 경우에만 동일 shard를 한 번 다시 실행한다.
  echo "앱 테스트 러너 시작 실패로 동일 shard를 한 번 다시 실행합니다." | tee -a "$TEST_LOG_PATH"
  rm -rf "$RESULT_BUNDLE" "$TEST_RUN_REPORT_PATH"
  run_tests 2>&1 | tee -a "$TEST_LOG_PATH"
else
  exit 1
fi

if [[ ! -s "$TEST_RUN_REPORT_PATH" ]]; then
  echo "Tuist test run이 서버 dashboard URL을 기록하지 못했습니다: $TEST_RUN_REPORT_PATH" >&2
  exit 1
fi

./Scripts/check-xcresult-summary.sh "$RESULT_BUNDLE"
