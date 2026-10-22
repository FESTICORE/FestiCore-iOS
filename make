#!/bin/sh
set -eu

script_dir=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
cd "$script_dir"
exec /usr/bin/swift "$script_dir/TuistTool.swift" "$@"
