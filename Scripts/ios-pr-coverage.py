#!/usr/bin/env python3

"""Render an xcodebuild result bundle as a short PR coverage report."""

import json
import subprocess
import sys
from pathlib import Path


bundle = Path(sys.argv[1])
if not bundle.exists():
    print("테스트 결과 번들이 없어 커버리지를 확인할 수 없습니다.")
    raise SystemExit(0)

result = subprocess.run(
    ["xcrun", "xccov", "view", "--report", "--json", "--only-targets", str(bundle)],
    capture_output=True,
    text=True,
)
if result.returncode:
    print("커버리지 보고서를 읽지 못했습니다.")
    raise SystemExit(1)

targets = [
    target for target in json.loads(result.stdout)
    if not target["name"].endswith(".xctest") and target["executableLines"] > 0
]
covered = sum(target["coveredLines"] for target in targets)
executable = sum(target["executableLines"] for target in targets)
if not executable:
    print("측정 가능한 앱 코드가 없습니다.")
    raise SystemExit(1)

print(f"**전체 앱 코드 커버리지: {covered / executable:.1%}** ({covered}/{executable}줄)\n")
print("| 타깃 | 커버리지 | 실행 줄 |")
print("| --- | ---: | ---: |")
for target in targets:
    lines = target["executableLines"]
    ratio = target["coveredLines"] / lines
    print(f"| {target['name']} | {ratio:.1%} | {target['coveredLines']}/{lines} |")
