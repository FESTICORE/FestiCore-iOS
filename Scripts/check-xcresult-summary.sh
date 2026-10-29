#!/usr/bin/env bash

set -euo pipefail

readonly RESULT_BUNDLE="${1:?테스트 결과 번들 경로가 필요합니다}"

if [[ ! -d "$RESULT_BUNDLE" ]]; then
  echo "테스트 결과 번들이 생성되지 않았습니다: $RESULT_BUNDLE" >&2
  exit 1
fi

xcrun xcresulttool get test-results summary \
  --path "$RESULT_BUNDLE" \
  --format json \
  | ruby -rjson -e '
    summary = JSON.parse(STDIN.read)
    result = summary["result"]
    failed = summary["failedTests"]
    count = summary["totalTestCount"]
    unless result == "Passed" && failed == 0 && count.is_a?(Integer) && count.positive?
      warn "테스트 결과 실패: result=#{result.inspect}, failedTests=#{failed.inspect}, totalTestCount=#{count.inspect}"
      exit 1
    end
    puts "테스트 결과 통과: #{count}개 (#{ARGV.fetch(0)})"
  ' "$RESULT_BUNDLE"
