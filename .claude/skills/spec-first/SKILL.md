---
name: spec-first
description: FestiCore에서 기능을 만들거나 동작을 바꾸기 전에 spec을 먼저 쓸 때 사용한다. 기능 spec(모듈 .spec/<기능>.md)과 설계 문서(.claude/docs/specs/) 중 무엇을 쓸지 판단, 소유 모듈 위치 정하기, 템플릿 채우기, 기존 spec 갱신(작업 모듈 · 영향 범위 · 변경 이력), 미해결 질문 정리. 새 Feature · Domain · Core · Service 모듈, 화면 흐름, API 동작, 인증 · 저장소 방식 변경을 시작할 때 쓴다. 구현은 tca-feature · screen-flow · tuist 스킬로 넘어간다. 완료 체크리스트(checklist.md)로 스스로 검증한다.
---

# Spec 먼저 쓰기 (FestiCore)

규칙 원본: `.claude/docs/spec-guide.md`. 이 스킬은 순서만 담는다. 다르면 문서가 우선이다.

## 1. 무엇을 쓸지 정한다

두 가지를 모두 써야 할 수도 있다. 아래 표를 위에서부터 본다.

| 변경 | 설계 문서 (`.claude/docs/specs/YYYY-MM-DD-<주제>-design.md`) | 기능 spec (`<소유 모듈>/.spec/<기능>.md`) |
| --- | --- | --- |
| 새 Feature · Domain · Core · Service 모듈 | 쓴다 | 쓴다 |
| 모듈 의존 방향 변경 | 쓴다 | 바뀌는 동작이 있으면 쓴다 |
| 네트워크 · 인증 · 저장소 방식, 빌드 · 배포 파이프라인 변경 | 쓴다 | 바뀌는 동작이 있으면 쓴다 |
| 기존 모듈 안의 기능 추가 · 동작 변경 | 쓰지 않는다 | 쓴다 |
| 버그 수정 · 문구 · 스타일 · 테스트 추가 · 설정 값 | 쓰지 않는다 | 동작 규칙이 바뀔 때만 갱신 |

## 2. 기능 spec 위치

- 업무 규칙 · API 동작은 `Projects/Domain/<기능>Domain/.spec/`, 화면 동작은 `Projects/Feature/<기능>/.spec/`, 앱 전체 흐름(Coordinator · 딥링크 · 푸시)은 `Projects/App/.spec/`.
- 파일 이름은 기능을 설명하는 kebab-case(`social-login.md`). 이슈 번호를 쓰지 않는다.
- 먼저 `find Projects -path '*/.spec/*.md' -not -path '*/Derived/*'`로 같은 기능 spec이 있는지 본다. 있으면 새로 만들지 않고 갱신한다.

## 3. 채우기

형식은 spec-guide.md의 템플릿을 그대로 쓴다(frontmatter `spec` · `modules`, 개요 · 동작 규칙 · 엣지 케이스 · 제약 · 작업 모듈 · 영향 범위 · 미해결 질문 · 변경 이력).

- "어떻게"가 아니라 "무엇이 참이어야 하는가"를 쓴다. 각 규칙은 테스트 하나로 확인할 수 있게 쓴다.
- 확인하지 않은 내용은 추측으로 쓰지 않고 `미해결 질문`에 둔다. 구현을 막는 질문이면 사용자에게 묻는다.
- 구조는 Attendance_iOS의 같은 역할 파일과 대조해 적는다(`.claude/docs/architecture.md`).
- 갱신할 때는 요청 범위만 고친다. 작업 모듈 · 영향 범위 · 미해결 질문은 이번 이슈 기준으로 새로 쓰고, 변경 이력 맨 위에 `- #<이슈> 한 줄 요약`을 더한다.

## 4. 올리기

- spec은 작업 PR의 첫 커밋(`<기능> spec을 추가한다 #N`)으로 올린다. 설계 문서가 필요하면 합의 전에 구현하지 않는다.
- 구현 중 동작이 바뀌면 코드보다 spec을 먼저 고친다.

## 5. 다음 단계

| 작업 | 스킬 · 문서 |
| --- | --- |
| Domain · API · 저장소 | `.claude/docs/domain-modules.md` · `.claude/docs/storage.md` |
| 화면 · Reducer | `tca-feature` |
| 화면 사이 이동 · 앱 흐름 | `screen-flow` |
| 모듈 생성 · 의존 | `tuist` |

spec의 동작 규칙마다 테스트가 하나씩 있는지 PR 전에 대조한다.

## 6. 완료 체크리스트

spec을 올리기 전에 `checklist.md`를 확인한다. 못 채운 항목이 있으면 올리지 않고 무엇이 남았는지 보고한다. spec 규칙과 실제 테스트의 대조는 구현 스킬(`tca-feature` · `screen-flow`)의 체크리스트에서 한다.

작업 중 틀렸다는 지적을 받으면 채팅에서 고치고 끝내지 않는다. 같은 PR에서 원인이 된 문서 · 이 스킬 · `checklist.md`를 고친다.
