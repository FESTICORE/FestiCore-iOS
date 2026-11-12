#!/bin/bash
# 스테이징된 Swift 파일 검사. git commit 앞에서 check_git_rules.py가 저장소 루트를 작업 폴더로 두고 부른다.
# staged Swift 파일에 SwiftFormat/SwiftLint를 적용하고 check-swift-conventions.py --staged로 규칙을 본다.
# 직접 실행: 저장소 루트에서 bash .claude/hooks/pre-commit-check.sh

files=$(git diff --cached --name-only --diff-filter=ACM 2>/dev/null | grep -E '\.swift$' | grep -vE '/\.build/|/Derived/|/DerivedData/')
[ -n "$files" ] || exit 0

if command -v swiftformat >/dev/null 2>&1; then
  while IFS= read -r file; do
    [ -f "$file" ] || continue
    # 스테이징하지 않은 변경이 함께 커밋되지 않도록, 작업 트리와 인덱스가 같은 파일만 포맷한다.
    if ! git diff --quiet -- "$file"; then
      printf '[SwiftFormat] %s에 스테이징하지 않은 변경이 있어 자동 포맷을 건너뜁니다.\n' "$file" >&2
      continue
    fi
    if ! out=$(swiftformat "$file" 2>&1 >/dev/null); then
      printf '[SwiftFormat] %s 포맷에 실패해 커밋을 차단했습니다.\n%s\n' "$file" "$out" >&2
      exit 2
    fi
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

if ! python3 .claude/hooks/check-swift-conventions.py --staged; then
  printf '[Swift 규칙] staged Swift 파일의 필수 구조와 return을 확인하세요.\n' >&2
  exit 2
fi

exit 0
