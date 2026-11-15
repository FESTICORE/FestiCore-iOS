# AGENTS.md (Codex · 기타 에이전트용)

이 저장소의 규칙 원본은 `CLAUDE.md`와 `.claude/docs/`이다. Claude와 Codex는 같은 규칙으로 작업한다.
이 파일에는 규칙을 다시 쓰지 않는다. 규칙을 바꿀 때는 `CLAUDE.md`나 `.claude/docs/`를 고친다.

## 작업 시작 전

1. `CLAUDE.md`를 읽는다.
2. `CLAUDE.md`의 문서 색인에서 이번 작업에 해당하는 `.claude/docs/*.md`를 읽는다.
3. 수정할 경로에 맞는 경로별 규칙을 읽는다. Claude는 자동으로 적용하지만 Codex는 직접 읽어야 한다.

| 수정 경로 | 읽을 규칙 |
| --- | --- |
| `Projects/App/**`, `Projects/Extension/**` | `.claude/rules/app.md` |
| `Projects/Feature/**` | `.claude/rules/feature.md` |
| `Projects/Domain/**` | `.claude/rules/domain.md` |
| `Projects/Service/**`, `Projects/Core/**` | `.claude/rules/service-core.md` |
| `Projects/UI/**`, `Projects/Widget/**` | `.claude/rules/ui.md` |

## Codex가 직접 지켜야 하는 것

Claude는 `.claude/hooks/check-git-rules.sh` 훅이 아래 규칙을 강제한다. Codex에는 이 훅이 걸리지 않으니 직접 지킨다. Codex에는 `.codex/hooks.json`의 Swift 규칙 검사만 걸린다.

- `develop` · `main`에 직접 커밋 · 푸시하지 않는다.
- 브랜치 이름은 `feature/<작업명>`(영문 소문자 kebab-case)으로 짓는다.
- 커밋 제목과 본문은 한국어로 쓰고 제목 끝에 `#이슈번호`를 붙인다. `Co-Authored-By`를 넣지 않는다.
- `.DS_Store`를 커밋하지 않는다.
- 스테이징된 Swift는 `.claude/hooks/pre-commit-check.sh`(SwiftFormat · SwiftLint · Swift 규칙 검사)를 통과해야 한다.
- 코드를 바꿨으면 커밋 전에 `.claude/scripts/verify`가 통과해야 한다. Claude는 통과 기록 없이 커밋하면 훅이 막는다.
- verify의 같은 단계가 2번 연속 실패하면 멈추고 사용자에게 보고한다. 승인 없이 세 번째 시도를 하지 않는다.

커밋 전에 같은 검사를 직접 실행한다.

```bash
.claude/scripts/verify < /dev/null                                               # 바뀐 경로에 맞는 검사 · 생성 · 테스트
bash .claude/hooks/check-git-rules.sh --check-message "하네스를 맞춘다 #396" < /dev/null   # 제목 한 줄만 넘긴다
bash .claude/hooks/check-git-rules.sh --check-branch "feature/agent-harness" < /dev/null
bash .claude/hooks/pre-commit-check.sh < /dev/null                               # 저장소 루트에서, 스테이징된 Swift
```

## 리뷰를 맡았을 때

- `CLAUDE.md`의 Hard 규칙과 해당 `.claude/docs` 문서를 기준으로 본다.
- 의존 방향(`.claude/docs/architecture.md`)과 주입 범위(`.claude/docs/domain-modules.md`, `.claude/docs/dependency-injection.md`) 위반을 먼저 확인한다.
- 지적에는 파일 경로와 줄 번호, 위반한 규칙 문서를 함께 적는다.

## Claudex Loop

사용자 작업을 시작할 때 설치된 `claudex-loop` 스킬을 읽고 현재 호스트가 Codex인지 Claude인지 확인한다. 계획만 요청받으면 상대 CLI의 계획 검토까지, 구현을 요청받으면 계획 검토와 구현 후 교차 점검까지 수행한다. 검토자·구현자·점검자 세션은 맡은 역할만 수행하며 루프를 다시 시작하지 않는다. 상대 CLI를 사용할 수 없으면 검토가 완료되지 않았다고 명확히 보고한다. 사용자 승인 범위를 그대로 지킨다.
