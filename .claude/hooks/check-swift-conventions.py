#!/usr/bin/env python3
"""Check high-confidence Swift conventions without rewriting source files."""

import argparse
import json
import pathlib
import re
import subprocess
import sys


DECLARATION = re.compile(
    r"(?P<builder>@ViewBuilder\s+)?(?:(?:public|private|internal|fileprivate|static|class|"
    r"nonisolated|override|final|mutating|nonmutating|async|throws)\s+)*"
    r"(?P<kind>func|var)\s+(?P<name>[A-Za-z_][\w]*)\b(?P<signature>[^{};]*?)\{",
    re.MULTILINE,
)
SCREEN = re.compile(r"(?:public\s+)?struct\s+(\w+View)\s*:\s*View\s*\{")
REDUCER = re.compile(r"@Reducer\s+(?:public\s+)?(?:struct|enum)\s+(\w+Feature)\b")
PARAMETER_DECLARATION = re.compile(
    r"^[ \t]*(?:(?:public|private|internal|fileprivate|static|class|nonisolated|"
    r"override|final|mutating|nonmutating|required|convenience|distributed)\s+)*"
    r"(?:func\s+([A-Za-z_][\w]*)|init[?!]?)\s*(?:<[^()\n]+>)?\s*\(",
    re.MULTILINE,
)


def masked(source: str) -> str:
    """Blank strings/comments while preserving offsets and newlines."""
    chars = list(source)
    i = 0
    while i < len(chars):
        if source.startswith("//", i):
            end = source.find("\n", i)
            end = len(chars) if end < 0 else end
        elif source.startswith("/*", i):
            depth, end = 1, i + 2
            while end < len(chars) and depth:
                if source.startswith("/*", end):
                    depth, end = depth + 1, end + 2
                elif source.startswith("*/", end):
                    depth, end = depth - 1, end + 2
                else:
                    end += 1
        elif source[i] == '"':
            delimiter = '"""' if source.startswith('"""', i) else '"'
            end = i + len(delimiter)
            while end < len(chars):
                if source[end] == "\\":
                    end += 2
                elif source.startswith(delimiter, end):
                    end += len(delimiter)
                    break
                else:
                    end += 1
        else:
            i += 1
            continue
        for j in range(i, min(end, len(chars))):
            if chars[j] != "\n":
                chars[j] = " "
        i = end
    return "".join(chars)


def closing_brace(code: str, opening: int) -> int:
    depth = 0
    for i in range(opening, len(code)):
        if code[i] == "{":
            depth += 1
        elif code[i] == "}":
            depth -= 1
            if depth == 0:
                return i
    return len(code)


def top_level_statements(code: str) -> list[str]:
    statements = []
    depth = 0
    current = []
    for char in code:
        if char in "({[":
            depth += 1
        elif char in ")}]":
            depth -= 1
        if depth == 0 and char in ";\n":
            text = "".join(current).strip()
            if text:
                statements.append(text)
            current = []
        else:
            current.append(char)
    text = "".join(current).strip()
    if text:
        statements.append(text)
    return statements


def parameter_positions(code: str, opening: int) -> tuple[list[int], int] | None:
    """Find parameter starts, ignoring commas nested in Swift types/default values."""
    depths = {"(": 0, "[": 0, "{": 0, "<": 0}
    pairs = {")": "(", "]": "[", "}": "{", ">": "<"}
    starts = []
    segment_start = opening + 1
    for index in range(opening + 1, len(code)):
        char = code[index]
        if char == ")" and not any(depths.values()):
            if code[segment_start:index].strip():
                starts.append(segment_start + len(code[segment_start:index]) - len(code[segment_start:index].lstrip()))
            return starts, index
        if char in "([{":
            depths[char] += 1
        elif char == "<":
            depths[char] += 1
        elif char in ")]}" and depths[pairs[char]]:
            depths[pairs[char]] -= 1
        elif char == ">" and index > 0 and code[index - 1] != "-" and depths["<"]:
            depths["<"] -= 1
        elif char == "," and not any(depths.values()):
            segment = code[segment_start:index]
            if segment.strip():
                starts.append(segment_start + len(segment) - len(segment.lstrip()))
            segment_start = index + 1
    return None


def check(source: str, name: str, changed_lines: set[int] | None = None) -> list[str]:
    code = masked(source)
    issues = []
    for match in PARAMETER_DECLARATION.finditer(code):
        opening = match.end() - 1
        parsed = parameter_positions(code, opening)
        if parsed is None:
            continue
        starts, closing = parsed
        if len(starts) < 2:
            continue
        first_line = source.count("\n", 0, match.start()) + 1
        last_line = source.count("\n", 0, closing) + 1
        if changed_lines is not None and not any(line in changed_lines for line in range(first_line, last_line + 1)):
            continue
        parameter_lines = [source.count("\n", 0, start) + 1 for start in starts]
        if parameter_lines[0] == source.count("\n", 0, opening) + 1 or len(set(parameter_lines)) != len(parameter_lines):
            identifier = match.group(1) or "init"
            issues.append(f"{name}:{first_line}: {identifier}: 파라미터가 2개 이상이면 각 파라미터를 새 줄에 작성하세요")
    for match in DECLARATION.finditer(code):
        signature = match.group("signature")
        kind, identifier = match.group("kind", "name")
        # Stored properties have no body; their next brace may belong to a later declaration.
        if kind == "var" and ("\n" in signature or "=" in signature):
            continue
        if kind == "func" and "\n\n" in signature:
            continue
        # A closure default value can open a brace before the declaration body.
        if kind == "func" and signature.count("(") > signature.count(")"):
            continue
        if kind == "func" and "->" not in signature:
            continue
        if kind == "var" and ":" not in signature:
            continue
        if identifier == "body" or match.group("builder") or "some View" in signature and "@ViewBuilder" in code[max(0, match.start() - 80):match.start()]:
            continue
        opening = match.end() - 1
        body = code[opening + 1:closing_brace(code, opening)]
        statements = top_level_statements(body)
        if name.endswith("View.swift") and "some View" in signature and identifier != "body":
            is_stack = bool(re.match(r"\s*(?:VStack|HStack|ZStack|LazyVStack|LazyHStack)\s*(?:\(|\{)", body))
            is_multiple_views = len(statements) > 1 and all(
                re.match(r"^(?:Text|Image|Button|Spacer|Color|Group|(?:Lazy)?[VHZ]Stack|FC[A-Z]\w*)\b", statement)
                for statement in statements
            )
            line = source.count("\n", 0, match.start()) + 1
            if changed_lines is not None and line not in changed_lines:
                continue
            if kind == "var" and (is_stack or is_multiple_views):
                issues.append(f"{name}:{line}: var {identifier}: 여러 View 섹션은 @ViewBuilder func로 분리하세요")
            if kind == "func" and (is_stack or is_multiple_views) and not match.group("builder"):
                issues.append(f"{name}:{line}: func {identifier}: 여러 View 섹션에 @ViewBuilder를 선언하세요")
            if is_stack or is_multiple_views:
                continue
        if len(statements) != 1:
            continue
        expression = statements[0]
        if re.match(r"^(?:return|throw|guard|if|switch|for|while|do|defer|let|var|#|@)\b", expression):
            continue
        if expression.startswith(("get", "set", "willSet", "didSet")):
            continue
        line = source.count("\n", 0, match.start()) + 1
        if changed_lines is not None and line not in changed_lines:
            continue
        issues.append(f"{name}:{line}: {kind} {identifier}: 단일 반환식에 명시적 return을 쓰세요")

    # Structural checks are intentionally restricted to screen/reducer declarations.
    for match in SCREEN.finditer(code):
        block = code[match.end():closing_brace(code, match.end() - 1)]
        if "StoreOf<" in block and "@ViewAction" not in code[max(0, match.start() - 120):match.start()]:
            line = source.count("\n", 0, match.start()) + 1
            if changed_lines is not None and line not in changed_lines:
                continue
            issues.append(f"{name}:{line}: {match.group(1)}: Store 화면에 @ViewAction을 선언하세요")
    for match in REDUCER.finditer(code):
        block = code[match.end():closing_brace(code, code.find("{", match.end()))]
        if "case view(View)" in block and "handleViewAction" not in block:
            line = source.count("\n", 0, match.start()) + 1
            if changed_lines is not None and line not in changed_lines:
                continue
            issues.append(f"{name}:{line}: {match.group(1)}: view 액션을 handleViewAction으로 분리하세요")
    return issues


def diff_lines(path: str, staged: bool) -> set[int]:
    command = ["git", "diff", "--cached" if staged else "HEAD", "--unified=0", "--", path]
    result = subprocess.run(command, capture_output=True, text=True)
    if result.returncode:
        return set()
    lines = set()
    for match in re.finditer(r"^@@ -\d+(?:,\d+)? \+(\d+)(?:,(\d+))? @@", result.stdout, re.MULTILINE):
        first = int(match.group(1))
        count = int(match.group(2) or 1)
        lines.update(range(first, first + count))
    return lines


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("files", nargs="*")
    parser.add_argument("--staged", action="store_true")
    parser.add_argument("--stdin-filename")
    parser.add_argument("--hook", action="store_true")
    args = parser.parse_args()
    if args.hook:
        event = json.load(sys.stdin)
        tool = event.get("tool_name", "")
        tool_input = event.get("tool_input") or {}
        if tool in {"Edit", "Write", "MultiEdit"}:
            paths = [tool_input.get("file_path") or tool_input.get("path")]
            paths += [edit.get("file_path") for edit in tool_input.get("edits", []) if isinstance(edit, dict)]
        elif tool in {"Bash", "apply_patch", "exec_command"}:
            result = subprocess.run(
                ["git", "status", "--porcelain", "--untracked-files=all"],
                capture_output=True, text=True,
            )
            paths = [line[3:] for line in result.stdout.splitlines() if len(line) > 3]
        else:
            paths = []
        repo = pathlib.Path.cwd().resolve()
        paths = list(dict.fromkeys(path for path in paths if path and path.endswith(".swift")))
        safe_paths = []
        for path in paths:
            candidate = pathlib.Path(path).resolve()
            if candidate.is_relative_to(repo) and candidate.is_file():
                relative = str(candidate.relative_to(repo))
                tracked = subprocess.run(["git", "ls-files", "--error-unmatch", "--", relative],
                                         capture_output=True).returncode == 0
                lines = diff_lines(relative, staged=False) if tracked else set(range(1, len(candidate.read_text().splitlines()) + 1))
                safe_paths.append((relative, candidate.read_text(), lines))
        items = safe_paths
        issues = [issue for name, source, lines in items for issue in check(source, name, lines)]
        if issues:
            print(json.dumps({"hookSpecificOutput": {"hookEventName": "PostToolUse", "additionalContext":
                "Swift 규칙 검사:\n" + "\n".join(issues[:20]) +
                (f"\n... 외 {len(issues) - 20}건" if len(issues) > 20 else "")}}, ensure_ascii=False))
        return 0
    if args.stdin_filename:
        items = [(args.stdin_filename, sys.stdin.read())]
    else:
        items = []
        if args.staged and not args.files:
            result = subprocess.run(
                ["git", "diff", "--cached", "--name-only", "--diff-filter=ACM"],
                capture_output=True, text=True,
            )
            args.files = result.stdout.splitlines()
        for file in args.files:
            path = pathlib.Path(file)
            if path.suffix != ".swift":
                continue
            if args.staged:
                result = subprocess.run(["git", "show", f":{file}"], capture_output=True, text=True)
                if result.returncode:
                    continue
                items.append((file, result.stdout, diff_lines(file, staged=True)))
            elif path.is_file():
                items.append((file, path.read_text(), None))
    issues = [issue for name, source, lines in items for issue in check(source, name, lines)]
    if issues:
        print("\n".join(issues), file=sys.stderr)
    return 1 if issues else 0


if __name__ == "__main__":
    raise SystemExit(main())
