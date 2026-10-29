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

rm -rf -- "$expected"
