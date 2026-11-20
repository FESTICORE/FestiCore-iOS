# 에이전트 하네스

하네스는 에이전트가 일하는 환경 전체다. 규칙 문서, 경로별 규칙, 스킬, 훅, 검증 스크립트로 이루어진다. 구조는 CIRQLE-Native-Mobile의 하네스를 FestiCore 규칙에 맞게 옮겼다.

- 프롬프트 지시는 확률이고 실행되는 검사는 보장이다. 같은 실수가 반복되면 문서보다 검사로 막는다.
- 세 축으로 관리한다. **Context**(무엇을 읽게 할지) · **Control**(무엇을 막고 확인할지) · **Observability**(무엇이 쓰이는지 보고 정리).
- 규칙 파일은 200줄 미만으로 두고 경로별로 나눠 해당 파일을 다룰 때만 읽게 한다. 규칙은 Hard(반드시)와 Soft(기존 코드가 다르면 기존 코드)를 나눈다.

## 구성

| 종류 | 위치 | 역할 | 언제 읽히나 |
| --- | --- | --- | --- |
| 프로젝트 규칙 | `CLAUDE.md` | 개요 · Hard 규칙 · 문서 색인 · 명령 | 세션 시작 시 항상 |
| Codex 진입점 | `AGENTS.md` | `CLAUDE.md`와 `.claude/docs`를 읽으라는 안내 · 경로별 규칙 표 · Claudex Loop | Codex 세션 시작 시 |
| 상세 문서 | `.claude/docs/*.md` | 영역별 규칙과 예시 | 작업에 맞는 문서를 골라 읽음 |
| 설계 | `.claude/docs/specs/*.md` | 구현 전 합의한 설계([Spec 가이드](spec-guide.md)) | 해당 작업 시 |
| 경로별 규칙 | `.claude/rules/*.md` | frontmatter `paths`에 맞는 파일을 다룰 때 적용 | 자동 (Claude) · 직접 (Codex) |
| 스킬 | `.claude/skills/*/SKILL.md` | 작업 순서 · 외부 Swift 스킬(출처는 `THIRD_PARTY_NOTICES.md`) | 작업이 스킬 설명과 맞을 때 |
| 에이전트 | `.claude/agents/*.md` | 테스트 · PR 전용 에이전트 | 직접 부를 때 |
| 훅 | `.claude/hooks/*` + `.claude/settings.json` | 규칙을 실행으로 강제 · 사용 기록 | 도구 실행 전후 · 응답 종료 시 |
| 스크립트 | `.claude/scripts/verify` · `check-boundaries` · `check-security` · `file-header` · `harness-report` | 검증 · 모듈 경계 · 보안 · 새 파일 헤더 · 사용 리포트 | 직접 실행 · verify가 실행 |
| 로컬 상태 | `.claude/state/` (git 제외) | 검증 기록(`verify.json`) · 검증 로그 · 사용 기록 | 훅 · 스크립트가 읽고 씀 |

`docs/`의 문서는 사람이 읽는 설계 · 운영 문서다. 에이전트 규칙은 `CLAUDE.md`와 `.claude/docs/`에만 둔다.

### 스킬

| 스킬 | 쓰는 때 |
| --- | --- |
| `tca-feature` | 화면 Reducer · View · 테스트 |
| `screen-flow` | Coordinator · 화면 전환 |
| `tuist` | 모듈 생성 · 의존 추가 · 생성 오류 |
| `spec-first` | 기능 spec · 설계 문서 먼저 쓰기 |
| `swiftui-pro` · `swift-concurrency-pro` · `swift-testing-pro` | SwiftUI · 동시성 · Swift Testing 검토 (외부 스킬, 본문은 원본 그대로) |

CLI에 연결된 공유 iOS 스킬(개인 환경의 스킬)은 현재 환경과 작업 범위에 맞을 때만 사용한다.

### 작업 영역 매뉴얼 · 체크리스트

반복되는 작업 영역은 에이전트를 따로 만들지 않고 매뉴얼을 준다. 에이전트는 하나, 작업마다 같은 매뉴얼 · 스킬 · 체크리스트를 쓴다(CIRQLE-Native-Mobile과 같은 구성).

| 영역 | 매뉴얼 | 스킬 · 체크리스트 |
| --- | --- | --- |
| iOS 화면 | `.claude/docs/ios-tca.md` · `swiftui-patterns.md` | `tca-feature` · `checklist.md` |
| 화면 전환 | `.claude/docs/navigation.md` | `screen-flow` · `checklist.md` |
| 기능 spec | `.claude/docs/spec-guide.md` | `spec-first` · `checklist.md` |

- 완료 보고 전에 체크리스트 항목을 증거(명령 · 종료 코드 · 파일 경로)와 함께 확인하고 PR 본문에 옮긴다. 못 채운 항목이 있으면 완료로 보고하지 않는다.
- 작업 중 받은 지적은 채팅에서 끝내지 않고 같은 PR에서 원인이 된 매뉴얼 · 스킬 · 체크리스트를 고친다.

## 경로별 규칙

| 파일 | 적용 경로 |
| --- | --- |
| `.claude/rules/feature.md` | `Projects/Feature/**` |
| `.claude/rules/domain.md` | `Projects/Domain/**` |
| `.claude/rules/service-core.md` | `Projects/Service/**`, `Projects/Core/**` |
| `.claude/rules/ui.md` | `Projects/UI/**`, `Projects/Widget/**` |
| `.claude/rules/app.md` | `Projects/App/**`, `Projects/Extension/**` |

## 훅

| 이벤트 | 스크립트 | 내용 |
| --- | --- | --- |
| `PreToolUse` (Bash) | `check-git-rules.sh` → `check_git_rules.py` | 아래 커밋 · 푸시 검사 |
| `PostToolUse` (Edit · Write · MultiEdit · Bash) | `check-swift-conventions.py --hook` | 바뀐 Swift 줄의 규칙 위반을 알린다(막지 않음) |
| `PostToolUse` (Read · Skill) | `usage_log.py` | 하네스 문서(`.claude/docs/` · `CLAUDE.md` · `AGENTS.md`) · 규칙 · 에이전트 · 스킬 · 모듈 `.spec/` 사용을 `.claude/state/usage.jsonl`에 기록 |
| `Stop` | `stop_guard.py` | 검증 안 된 코드 변경이 있으면 응답 종료를 한 번 막고 verify를 안내 |

`git commit` · `git push` 검사 순서:

1. 브랜치: `develop` · `main`에서 커밋 · 푸시 금지, 이름은 `feature/<작업명>`(영문 소문자 kebab-case). `develop` · `main`으로 직접 푸시 · 삭제 금지.
2. 커밋 제목: 한국어로 쓰고 끝에 `#이슈번호`(예: `… #396`). 스쿼시 머지 제목의 ` (#510)`도 허용한다. `feat:` 같은 접두사는 요구하지 않는다.
3. 메시지 어디에도 `Co-Authored-By`(대소문자 무관, `--trailer` 포함)를 넣지 않는다.
4. `.DS_Store`가 스테이징돼 있으면 막는다.
5. 스테이징된 Swift: 기존 `pre-commit-check.sh`를 그대로 실행한다(SwiftFormat 적용 후 다시 stage, SwiftLint error, `check-swift-conventions.py --staged`).
6. 검증 게이트: 코드 변경이 있는데 `verify.json`의 통과 지문과 지금 작업 트리 지문이 다르면 막는다.
7. 게이트 우회 금지: `git commit`에 훅을 건너뛰는 옵션(긴 이름 · 축약 · `-n` · `-an` 같은 묶음, `bash -c` 안 포함)을 쓰거나 `core.hooksPath`를 바꾸는(`config` · `--unset` · `git -c core.hooksPath=…` · `GIT_CONFIG_KEY_n`/`GIT_CONFIG_PARAMETERS` 환경 변수) 명령을 막는다. 조회와 `.githooks`로 켜는 명령은 통과한다.

- 메시지는 `-m` · `--message` · `-F 파일` · `-F - <<EOF` · `-m "$(cat <<'EOF' … EOF)"`에서 읽는다. 편집기로 쓰거나 셸 변수인 제목은 실행 전에 알 수 없어 제목 검사를 건너뛴다.
- 5단계의 SwiftFormat이 파일을 고치면 지문이 바뀌어 6단계에서 막힌다. verify를 다시 돌린 뒤 커밋한다.
- 훅은 모든 Bash 명령마다 돈다. commit · push가 아니면 bash 문자열 비교만 하고 끝낸다. 해당하면 python을 `-I -S`로 한 번 띄운다. 브랜치는 `HEAD` 파일을 직접 읽고, worktree처럼 `.git`이 `gitdir: …` 파일이면 그 gitdir의 `HEAD`를 읽는다.
- `cd 경로 && git commit …`, `git -C 경로 commit …`은 그 경로의 저장소를 본다.
- 위반하면 `exit 2`와 stderr 메시지로 명령을 막는다. 고친 뒤 다시 실행한다.
- 개인 전역 gitignore가 `.claude/`를 무시하면 새 하네스 파일은 `git add -f`로 올린다. 지문 계산은 전역 gitignore를 보지 않고 저장소 `.gitignore`만 적용한다.

### git pre-commit 게이트 (`.githooks/pre-commit`)

Claude 훅은 `git commit` 명령만 보므로, 사람이 Xcode · 터미널에서 직접 커밋하거나 같은 명령 안에서 고친 뒤 `commit -a`하는 경우는 git 훅이 잡는다. `verify`가 실행될 때 `core.hooksPath`를 `.githooks`로 켠다.

1. `check-swift-conventions.py --staged`: 스테이징된 Swift 파일 규칙.
2. `pre_commit_gate.py`: 커밋될 index의 코드 파일을 `verify.json`의 `code`(통과 시점 파일별 `모드 blob`)와 대조한다. 하나라도 다르면 막는다. 지운 파일은 verify 때도 지워져 있어야 한다. 통과 기록이 없거나 `code`가 없는 옛 기록이면 코드 커밋을 막는다. 문서(`.md` · `DesignExports/`)만 담은 커밋은 보지 않는다.

- 검증 뒤 작업 트리만 더 고치고 스테이징하지 않았다면, index가 검증 내용과 같으므로 커밋된다.

직접 검사 (Codex 등 Claude 훅이 없는 환경은 커밋 전에 실행한다):

```bash
bash .claude/hooks/check-git-rules.sh --check-message "하네스를 맞춘다 #396" < /dev/null
bash .claude/hooks/check-git-rules.sh --check-branch "feature/agent-harness" < /dev/null
bash .claude/hooks/pre-commit-check.sh < /dev/null            # 저장소 루트에서, 스테이징된 Swift
python3 -m unittest discover -s .claude/hooks/tests < /dev/null
```

## 검증 게이트

```bash
.claude/scripts/verify < /dev/null          # develop 이후 바뀐 코드에 맞는 단계만
.claude/scripts/verify --all < /dev/null    # 모든 단계, ./make test 전체
```

| 바뀐 경로 | 단계 | 명령 |
| --- | --- | --- |
| `.claude/hooks/` · `.claude/scripts/` · `.claude/settings.json` · `.githooks/` | harness-syntax · harness-tests | `bash -n`(훅 셸 · `.githooks`) · settings.json 파싱, `python3 -m unittest discover -s .claude/hooks/tests` |
| 코드 변경 전체(`.github/workflows/` 포함) | security | `.claude/scripts/check-security` |
| `Projects/` | boundaries | `.claude/scripts/check-boundaries` |
| `*.swift` | swift-conventions | `python3 .claude/hooks/check-swift-conventions.py --base <develop 분기점>` |
| `*.swift` | file-header | `.claude/scripts/file-header --base <develop 분기점>`(새로 추가한 Swift 파일만) |
| `Projects/` · `Plugins/` · `Tuist/` · `Config/` · `Tuist.swift` · `Workspace.swift` · `TuistTool.swift` · `make` | (install) · generate · test | `Tuist/.build/checkouts`가 없으면 `mise exec -- tuist install`, `./make generate --no-open`, `./make test -only-testing:<바뀐 모듈>Tests` |

- 테스트 타깃은 `Projects/<계층>/<모듈>/…` → `<모듈>Tests`로 고른다. `Projects/App` 변경과 `FestiCore.xctestplan`에 테스트 타깃이 없는 모듈(FeatureAssembly · Widget · Extension 등)은 `FestiCoreTests`다. `Plugins/` · `Tuist/` · `Config/` · 루트 Tuist 파일 · 테스트 플랜이 바뀌면 `./make test` 전체를 돌린다.
- 앱 호스트 테스트는 git 제외 파일 `Projects/App/Resources/GoogleService-Info.plist`가 필요하다. 없으면 verify가 원본 checkout에서 복사하라는 안내와 함께 실패한다(새 worktree에서 자주 겪는다).
- `.md` · `DesignExports/`만 바뀌면 검증하지 않는다.
- 모든 명령은 stdin을 `/dev/null`로 닫고 실행한다. 출력은 `.claude/state/verify/<단계>.log`에 남기고 단계별 · 전체 소요 시간을 출력한다. 종료 코드를 파이프로 가리지 않는다.
- 통과하면 작업 트리 코드 내용의 지문과 코드 파일별 내용(`code`)을 `.claude/state/verify.json`에 남긴다. 커밋을 여러 개로 나눠도 내용이 같으면 다시 돌리지 않는다. 통과 후 코드를 한 줄이라도 고치면 다시 verify를 돌린다.
- 같은 단계가 연속 2번 실패하면 세 번째 시도 전에 시도한 내용과 실패 원인을 사용자에게 보고하고 승인을 받는다.

### 보안 검사 (`check-security`)

추적 파일과 아직 추적하지 않은 파일(.gitignore 제외)을 모두 본다. 하나라도 걸리면 실패한다.

| 검사 | 대상 | 막는 것 |
| --- | --- | --- |
| 비밀 값 | 바이너리를 뺀 모든 파일 | 개인 키, GitHub · Slack · Atlassian · AWS · Google 키, Slack 웹훅, Sentry DSN |
| 워크플로 셸 주입 | `.github/workflows/*.yml` | `run`에 외부에서 정할 수 있는 값(`github.head_ref`, 이슈 · PR · 댓글 · 리뷰 · 토론의 제목 · 본문, 브랜치 이름 · 라벨, 커밋 메시지 · 작성자)을 `${{ }}`로 바로 넣는 것. env로 받아 `"$VAR"`로 쓴다 |
| iOS ATS 예외 | `Projects/` · `Plugins/` Swift · plist, `Config/*.xcconfig` | `NSAllowsArbitraryLoads` · `NSExceptionAllowsInsecureHTTPLoads` |
| http 주소 | `Config/*.xcconfig` | `FESTICORE_*_URL` · `FESTICORE_*_HOST`가 `http:`로 시작 |

- 규칙을 더하려면 스크립트의 `FORBIDDEN` · `SECRET_PATTERNS`에 한 줄을 더하고 이 표에 같은 규칙을 적는다.
- CIRQLE-Native-Mobile의 `check-security`에서 범용 검사만 가져왔다. Android R8 · KMP 헤더 · iOS Release 심볼 제거 필수 검사는 FestiCore에 해당 설정이 없어 넣지 않았다.

### 모듈 경계 (`check-boundaries`)

[프로젝트와 구조](architecture.md)의 의존 방향을 import 문으로 확인한다. 규칙을 더하면 `CLAUDE.md`나 `.claude/docs/` 문서에 같은 규칙이 있는지 확인한다.

| 규칙 | 검사 대상 |
| --- | --- |
| Feature는 Domain 구현(`import <X>Domain`)을 import하지 않는다 | `Projects/Feature/*/Sources` · `Interface` (FeatureAssembly 제외, Tests · Demo 제외) |
| Feature는 `API` · `APIEndpoint` · `FestiCoreNetwork*` · `FestiCoreAuth*`를 import하지 않는다 | `Projects/Feature/*/Sources` · `Interface` |
| APIEndpoint는 Domain · Auth Service에 의존하지 않는다 | `Projects/Service/APIEndpoint/Sources` |
| App은 개별 Feature 구현을 import하지 않는다(`<X>Interface`는 허용) | `Projects/App/Sources` |
| Sentry · Mixpanel은 FestiCoreAnalytics에서만 쓴다 | `Projects/**` |

## 관측과 정리

```bash
.claude/scripts/harness-report < /dev/null            # 최근 30일
.claude/scripts/harness-report --days 90 < /dev/null
```

- 문서 · 규칙 · 에이전트 · 스킬별 읽은 횟수와 마지막 사용일, 기간 안에 한 번도 쓰이지 않은 항목을 보여준다. 기록에는 경로와 스킬 이름만 남긴다.
- 오래 안 읽힌 문서는 합치거나 지우고, 동작하지 않는 스킬은 고친다. 정리는 이슈 · PR로 한다.

## 겪은 문제와 한계

- 검증 명령 뒤 `| tail`은 종료 코드를 가린다. 로그 파일로 남기고 종료 코드를 직접 본다.
- `git stash`는 다른 세션의 변경을 날릴 수 있다. 지문 계산은 복사한 임시 index로 한다.
- 훅 단위 검사만 통과하고 실제 세션에서는 동작하지 않을 수 있다. 훅을 바꾸면 실제로 막히는지 본다.
- `codex exec` 등 외부 CLI는 stdin을 닫지 않으면 입력을 기다리며 멈춘다. `< /dev/null`을 붙인다.
- `cd 경로 && git commit`의 경로에 변수(`$DIR`)가 있으면 훅은 해석하지 못하고 훅 입력의 cwd를 본다.
- `./make test -only-testing:`은 바뀐 모듈의 테스트만 돌린다. 그 모듈에 의존하는 다른 모듈의 테스트는 CI의 전체 실행이 맡는다. 필요하면 `--all`을 쓴다.
- Codex에는 Claude 훅이 걸리지 않는다(`.codex/hooks.json`의 Swift 규칙 검사만 걸린다). Codex는 커밋 전에 위 직접 검사와 verify를 실행한다.
- 훅은 실수를 막는 장치이지 보안 경계가 아니다. `env git commit`·`sudo git commit`·`/usr/bin/git commit`처럼 `git`으로 시작하지 않는 명령, 셸 변수·편집기·파일로 준 커밋 메시지는 검사하지 않는다. 이런 형태로 검사를 피하지 않는다.
- `gh pr merge --squash`의 제목·본문은 훅이 검사하지 않는다. 스쿼시 머지 때 [Git/PR](git-workflow.md) 규칙대로 직접 지정하고 머지 후 커밋 메시지를 확인한다.
- 따옴표 안의 `; git commit` 같은 문자열도 커밋으로 볼 수 있다(오탐). feature 브랜치에서 올바른 검증 기록이 있으면 통과한다.

## Claude와 Codex

- 규칙 원본은 `CLAUDE.md`와 `.claude/docs/` 하나다. `AGENTS.md`에는 규칙을 복사하지 않고 읽을 위치와 Claudex Loop 안내만 적는다.
- 교차 검토: 한쪽이 계획하거나 구현하면 다른 쪽이 같은 문서를 기준으로 검토한다(`AGENTS.md`의 Claudex Loop).

## 하네스 관리

- 규칙을 바꾸면 같은 PR에서 문서와 훅을 함께 고친다.
- Claude Code의 공유 설정은 `.claude/settings.json`에 둔다. 개인 권한 · 기억 파일(`settings.local.json` 등)은 커밋하지 않는다.
- 에이전트가 같은 실수를 두 번 하면 문서에 적고, 반복되면 훅이나 check-boundaries 규칙으로 만든다.
- 필요 없어진 규칙과 훅은 지운다. 검증과 보호 브랜치 규칙은 남긴다.
