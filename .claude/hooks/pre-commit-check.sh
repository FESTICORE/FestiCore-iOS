#!/bin/bash
# Claude PreToolUse 검사 흐름.
# git commit 명령 앞에서 staged Swift 파일에 SwiftFormat/SwiftLint를 적용한다.

input=$(cat)
cmd=$(printf '%s' "$input" | /usr/bin/jq -r '.tool_input.command // empty' 2>/dev/null)
printf '%s' "$cmd" | grep -qE '\bgit\b.+\bcommit\b' || exit 0

cd "${CLAUDE_PROJECT_DIR:-.}" || exit 0
files=$(git diff --cached --name-only --diff-filter=ACM 2>/dev/null | grep -E '\.swift$' | grep -vE '/\.build/|/Derived/|/DerivedData/')
[ -n "$files" ] || exit 0

if command -v swiftformat >/dev/null 2>&1; then
  while IFS= read -r file; do
    [ -f "$file" ] || continue
    swiftformat "$file" >/dev/null 2>&1
    git add -- "$file" || exit 2
  done <<EOF
$files
EOF
fi

if command -v swiftlint >/dev/null 2>&1 && { [ -f .swiftlint.yml ] || [ -f .swiftlint.yaml ]; }; then
  lintout=$(printf '%s\n' "$files" | xargs swiftlint lint --quiet 2>/dev/null | grep -E ': error:' | head -10)
  if [ -n "$lintout" ]; then
    printf '[SwiftLint] 커밋을 차단했습니다.\n%s\n' "$lintout" >&2
    exit 2
  fi
fi

exit 0
