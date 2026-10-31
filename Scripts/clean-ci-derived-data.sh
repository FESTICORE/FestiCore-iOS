#!/usr/bin/env bash
set -euo pipefail

directory="${1:?CI DerivedData directory is required}"
if [[ ! "$directory" =~ ^FestiCore-[A-Za-z0-9_-]+$ \
  || ! "${GITHUB_RUN_ID:-}" =~ ^[0-9]+$ \
  || ! "${GITHUB_RUN_ATTEMPT:-}" =~ ^[0-9]+$ ]]; then
  echo "::error::Invalid FestiCore DerivedData directory" >&2
  exit 1
fi

# The setup action has not run when checkout or an earlier step fails.
if [[ -z "${CI_DERIVED_DATA:-}" ]]; then
  exit 0
fi

root="$HOME/ci-derived-data"
expected="$root/$directory-$GITHUB_RUN_ID-$GITHUB_RUN_ATTEMPT"
if [[ "$CI_DERIVED_DATA" != "$expected" || -L "$root" || -L "$expected" \
  || ( -e "$root" && ! -d "$root" ) \
  || ( -e "$expected" && ! -d "$expected" ) ]]; then
  echo "::error::Unsafe FestiCore DerivedData cleanup path" >&2
  exit 1
fi

if error_output="$(rm -rf -- "$expected" 2>&1)"; then
  exit 0
fi

# Tuist CAS 프록시가 빌드 종료 후 작은 태그 파일을 다시 만들 수 있다.
spool="$expected/CompilationCache.noindex/plugin/tuist-spool"
while IFS= read -r line; do
  case "$line" in
    "rm: $spool: Directory not empty" \
    | "rm: $expected/CompilationCache.noindex/plugin: Directory not empty" \
    | "rm: $expected/CompilationCache.noindex: Directory not empty" \
    | "rm: $expected: Directory not empty") ;;
    *) printf '%s\n' "$error_output" >&2; exit 1 ;;
  esac
done <<< "$error_output"

cache="$expected/CompilationCache.noindex"
plugin="$cache/plugin"
if [[ ! -d "$spool" || -L "$cache" || -L "$plugin" || -L "$spool" ]]; then
  printf '%s\n' "$error_output" >&2
  exit 1
fi

shopt -s nullglob dotglob
root_entries=("$expected"/*)
cache_entries=("$cache"/*)
plugin_entries=("$plugin"/*)
tags=("$spool"/*)
if [[ ${#root_entries[@]} -ne 1 || ${root_entries[0]} != "$cache" \
  || ${#cache_entries[@]} -ne 1 || ${cache_entries[0]} != "$plugin" \
  || ${#plugin_entries[@]} -ne 1 || ${plugin_entries[0]} != "$spool" \
  || ${#tags[@]} -eq 0 || ${#tags[@]} -gt 1000 ]]; then
  printf '%s\n' "$error_output" >&2
  exit 1
fi

for tag in "${tags[@]}"; do
  if [[ ! -f "$tag" || -L "$tag" || ! "${tag##*/}" =~ ^[0-9]+-[0-9]+\.tags$ ]]; then
    printf '%s\n' "$error_output" >&2
    exit 1
  fi
done

spool_kib="$(du -sk "$spool" | awk '{print $1}')"
if [[ ! "$spool_kib" =~ ^[0-9]+$ || "$spool_kib" -gt 1024 ]]; then
  printf '%s\n' "$error_output" >&2
  exit 1
fi

echo "::warning::Tuist CAS 프록시가 다시 만든 태그 파일 ${spool_kib}KiB를 남겼습니다: $spool" >&2
