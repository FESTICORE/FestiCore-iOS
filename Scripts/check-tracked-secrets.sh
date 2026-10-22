#!/usr/bin/env bash
set -euo pipefail

failed=0
while IFS= read -r -d '' file; do
  case "$file" in
    *.p8|*.p12|*.cer|*.mobileprovision|*client_secret*.json|*AuthKey_*.json|*GoogleService-Info.plist|.env|.env.*|*.env|*/.env|*/.env.*|Config/*.local.xcconfig|*.xcodeproj/*|*.xcworkspace/*|Derived/*|Tuist/.build/*)
      printf 'Forbidden tracked file: %s\n' "$file" >&2
      failed=1
      ;;
  esac

  if [[ -f "$file" ]] && grep -Iq . "$file"; then
    if grep -Eq -- '-----BEGIN [A-Z ]*PRIVATE KEY-----|"client_secret"[[:space:]]*:' "$file"; then
      printf 'Potential secret in: %s\n' "$file" >&2
      failed=1
    fi
  fi
done < <(git ls-files -z --cached --others --exclude-standard)

exit "$failed"
