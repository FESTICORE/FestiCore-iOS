#!/usr/bin/env python3

"""Summarize PR tests and internal coverage from an Xcode result bundle."""

import json
import os
import re
import subprocess
import sys
from pathlib import Path


ROOT = Path(__file__).resolve().parent.parent
PRODUCT_SUFFIX = re.compile(r"\.(?:framework|app|bundle|a|dylib)$")
MODULE_NAME = re.compile(r'Project\.makeModule\s*\([\s\S]*?\bname:\s*"([^"]+)"')


def internal_target_names():
    names = {"FestiCore"}
    for manifest in (ROOT / "Projects").rglob("Project.swift"):
        match = MODULE_NAME.search(manifest.read_text())
        if match:
            names.update((match.group(1), f"{match.group(1)}Interface"))
    return names


def read_json(*args):
    result = subprocess.run(args, capture_output=True, text=True, check=True)
    return json.loads(result.stdout)


def coverage_lines(targets, allowed):
    selected = []
    for target in targets:
        name = PRODUCT_SUFFIX.sub("", target.get("name", ""))
        executable = target.get("executableLines", 0)
        if name in allowed and executable > 0:
            selected.append((name, target.get("coveredLines", 0), executable))
    return sorted(selected)


def dashboard_url(value):
    if isinstance(value, str):
        return value if value.startswith("https://") and "/tests/test-runs/" in value else None
    if isinstance(value, dict):
        return next((url for child in value.values() if (url := dashboard_url(child))), None)
    if isinstance(value, list):
        return next((url for child in value if (url := dashboard_url(child))), None)
    return None


def render(summary, targets, outcome, report_url=None):
    passed = summary.get("passedTests", 0)
    failed = summary.get("failedTests", 0)
    skipped = summary.get("skippedTests", 0)
    total = summary.get("totalTestCount", passed + failed + skipped)
    status = "✅ 통과" if outcome == "success" and failed == 0 and total > 0 else "❌ 실패"
    lines = [f"### 테스트 {status}", "", f"**{passed} passed · {failed} failed · {skipped} skipped · 총 {total}개**", ""]
    if report_url:
        lines.extend((f"[Tuist 테스트 실행]({report_url})", ""))
    failures = summary.get("testFailures", [])
    if failures:
        lines.extend(("| 실패한 테스트 | 내용 |", "| --- | --- |"))
        for failure in failures[:20]:
            name = (failure.get("testIdentifierString") or failure.get("testName") or "(이름 없음)").replace("|", "\\|")
            message = failure.get("failureText", "").replace("|", "\\|").replace("\n", " ")[:300]
            lines.append(f"| {name} | {message} |")
        lines.append("")
    covered = sum(item[1] for item in targets)
    executable = sum(item[2] for item in targets)
    if not executable:
        lines.append("측정 가능한 자체 앱·모듈 코드가 없습니다.")
        return "\n".join(lines)
    lines.extend((f"### 자체 코드 커버리지 {covered / executable:.1%} ({covered}/{executable}줄)", "", "| 타깃 | 커버리지 | 실행 줄 |", "| --- | ---: | ---: |"))
    for name, target_covered, target_executable in targets:
        lines.append(f"| {name} | {target_covered / target_executable:.1%} | {target_covered}/{target_executable} |")
    return "\n".join(lines)


def main(bundle):
    if not bundle.exists():
        print("테스트 결과 번들이 없어 실행 건수와 커버리지를 확인할 수 없습니다.")
        return 1
    try:
        summary = read_json("xcrun", "xcresulttool", "get", "test-results", "summary", "--path", str(bundle))
        targets = read_json("xcrun", "xccov", "view", "--report", "--json", "--only-targets", str(bundle))
    except (subprocess.CalledProcessError, json.JSONDecodeError) as error:
        print(f"테스트 결과를 읽지 못했습니다: {error}")
        return 1
    report_path = Path(os.environ.get("TEST_RUN_REPORT", ""))
    report_url = None
    if report_path.is_file():
        try:
            report_url = dashboard_url(json.loads(report_path.read_text()))
        except json.JSONDecodeError:
            pass
    print(render(summary, coverage_lines(targets, internal_target_names()), os.environ.get("TEST_OUTCOME", "unknown"), report_url))
    return 0 if summary.get("totalTestCount", 0) > 0 else 1


if __name__ == "__main__":
    raise SystemExit(main(Path(sys.argv[1])))
