"""git pre-commit 게이트 본체. 커밋될 index의 코드가 verify 통과 시점과 다르면 커밋을 막는다. (.claude/docs/harness.md)

Claude 훅(check_git_rules.py)은 git commit 명령만 보지만, 이 게이트는 사람이 직접 커밋하거나
같은 명령 안에서 고친 뒤 commit -a 해도 실제 index로 판정한다.
"""
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))  # -I 실행이라 직접 넣는다
import harness_state as hs  # noqa: E402


def main():
    root = hs.repo_root(".")
    files = hs.staged_unverified(root)
    if not files:
        return 0
    shown = ", ".join(files[:5]) + (f" 외 {len(files) - 5}개" if len(files) > 5 else "")
    sys.stderr.write(f"[검증 게이트] 커밋할 코드가 verify 통과 시점과 다릅니다({shown}).\n"
                     ".claude/scripts/verify로 통과를 확인한 뒤 커밋하세요. 규칙: .claude/docs/harness.md\n")
    return 1


if __name__ == "__main__":
    sys.exit(main())
