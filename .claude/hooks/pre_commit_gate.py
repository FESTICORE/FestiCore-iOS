"""git pre-commit 게이트 본체. 보호 브랜치 커밋과, 커밋될 index의 코드가 verify 통과 시점과 다른 커밋을 막는다. (.claude/docs/harness.md)

Claude 훅(check_git_rules.py)은 git commit 명령만 보지만, 이 게이트는 사람이 직접 커밋하거나
같은 명령 안에서 고친 뒤 commit -a 해도 실제 index로 판정한다.
"""
import os
import subprocess
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))  # -I 실행이라 직접 넣는다
import harness_state as hs  # noqa: E402


PROTECTED = {"main", "develop"}  # check_git_rules.py와 같게 둔다


def main():
    root = hs.repo_root(".")
    # PreToolUse 훅은 명령 시작 때 브랜치를 본다. 그 사이 다른 세션이 브랜치를 바꿔도 커밋 순간에 다시 막는다
    ref = subprocess.run(["git", "-C", root, "symbolic-ref", "-q", "HEAD"], capture_output=True, text=True,
                         stdin=subprocess.DEVNULL).stdout.strip()
    branch = ref.removeprefix("refs/heads/")  # --short는 같은 이름 태그가 있으면 heads/release로 줄여 비교를 빠져나간다
    if ref.startswith("refs/heads/") and branch in PROTECTED:
        sys.stderr.write(f"[git 규칙] 보호 브랜치 '{branch}'에는 커밋하지 않습니다. "
                         "feature 브랜치에서 PR로 머지하세요. 규칙: .claude/docs/git-workflow.md\n")
        return 1
    if "--branch-only" in sys.argv[1:]:  # pre-merge-commit: 병합 커밋은 브랜치만 본다
        return 0
    files = hs.staged_unverified(root)
    if not files:
        return 0
    shown = ", ".join(files[:5]) + (f" 외 {len(files) - 5}개" if len(files) > 5 else "")
    sys.stderr.write(f"[검증 게이트] 커밋할 코드가 verify 통과 시점과 다릅니다({shown}).\n"
                     ".claude/scripts/verify로 통과를 확인한 뒤 커밋하세요. 규칙: .claude/docs/harness.md\n")
    return 1


if __name__ == "__main__":
    sys.exit(main())
