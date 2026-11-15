# Spec 작성 가이드

구현 전에 "무엇이 참이어야 하는가"를 글로 남기고 검토받는다. 코드보다 spec을 먼저 리뷰받으면 되돌리는 비용이 작다.

spec은 두 종류다.

| 종류 | 위치 | 다루는 것 | 수명 |
| --- | --- | --- | --- |
| **기능 spec** | 기능을 소유한 모듈의 `.spec/<기능>.md` | 기능의 동작 규칙 · 엣지 케이스 · 작업 모듈 · 영향 범위 | 계속 갱신하는 단일 소스 |
| **설계 문서** | `.claude/docs/specs/YYYY-MM-DD-<주제>-design.md` | 모듈 구조 · 의존 방향 · 기술 선택 같은 여러 모듈에 걸친 결정 | 결정 시점 기록 |

`docs/`의 설계 문서(`docs/architecture/`, `docs/live-activity*.md` 등)는 사람이 읽는 문서라 그대로 둔다. 에이전트가 새로 쓰는 설계 문서는 `.claude/docs/specs/`에 둔다.

## 기능 spec (`.spec/`)

### 위치: 기능을 소유한 모듈 아래

코드와 같은 자리에서 관리한다. 동작 규칙이 Domain에 있으면 Domain 모듈이 소유한다.

| 소유 모듈 | 경로 예 |
| --- | --- |
| Domain (업무 규칙 · API 동작) | `Projects/Domain/AuthDomain/.spec/social-login.md` |
| Core · Service | `Projects/Core/FestiCoreNetwork/.spec/token-refresh.md` |
| Feature (화면 동작) | `Projects/Feature/Auth/.spec/login-screen.md` |
| 앱 전체 흐름 (Coordinator · 딥링크 · 푸시) | `Projects/App/.spec/` |

- 파일 이름은 이슈 번호가 아니라 **기능을 설명하는 이름**(kebab-case)으로 짓는다.
- 해당 기능 spec이 이미 있으면 새로 만들지 않고 그 문서를 갱신한다.

### 형식

```markdown
---
spec: social-login
modules: [Projects/Domain/AuthDomain, Projects/Feature/Auth]
---

# 소셜 로그인 Spec

> 한 문장 요약

## 개요
무엇이고 왜 있는가.

## 동작 규칙
입력 / 출력 / 상태 / 규칙. "어떻게"가 아니라 "무엇이 참이어야 하는가".

## 다이어그램
필요할 때만 Mermaid (flowchart · sequenceDiagram · classDiagram).

## 엣지 케이스
경계 · 예외와 기대 동작. 없으면 (없음).

## 제약 / 가정
의존 규칙, 이번 분석의 가정.

## 작업 모듈
| 모듈 | 계층 | 변경 내용 |   ← 이슈마다 갱신

## 영향 범위
| 모듈 | 계층 | 영향 이유 |   ← 이슈마다 갱신

## 미해결 질문
구현 전에 확인할 것. 없으면 (없음).

## 변경 이력
- #12 Apple 로그인 동작 규칙 추가   ← 최신순 한 줄
```

### 갱신 규칙

- 요청 범위만 고친다. 관계없는 기존 동작 규칙은 건드리지 않는다.
- 작업 모듈 · 영향 범위 · 미해결 질문은 이번 이슈 기준으로 새로 쓴다.
- 구현하다 동작이 바뀌면 코드보다 spec을 먼저 고친다.
- 변경 이력에 이슈 번호와 한 줄 요약을 남긴다.

## 설계 문서 (`.claude/docs/specs/`)

### 언제 쓰나

| 반드시 쓴다 | 쓰지 않아도 된다 |
| --- | --- |
| 새 Domain · Feature · Core · Service 모듈 | 한 모듈 안의 버그 수정 |
| 모듈 의존 방향 변경 | 화면 문구 · 스타일 수정 |
| 네트워크 · 인증 · 저장소 방식 변경 | 테스트 추가 |
| 빌드 · 배포 파이프라인 변경 | 설정 값 변경 |

### 형식

```markdown
# {제목}

- 날짜: YYYY-MM-DD
- 이슈: #{번호}
- 상태: 제안 | 합의 | 구현 완료 | 폐기
- 범위: 바뀌는 모듈 · 파일 경로

## 문제
## 목표 / 목표가 아닌 것
## 설계
## 결정 사항
| 결정 | 선택 | 대안 | 이유 |
## 결정 필요
## 검증
완료를 판단할 명령과 기대 결과. (예: `./make test -only-testing:AuthDomainTests` 통과)
## 단계
PR 단위로 나눈 구현 순서.
```

## 작성 원칙 (두 종류 공통)

- 추측은 쓰지 않는다. 확인하지 않은 내용은 `미해결 질문` · `결정 필요`에 둔다.
- 대안과 버린 이유를 함께 적는다. 같은 논의를 반복하지 않기 위해서다.
- 라이브러리 버전과 API는 공식 문서나 소스로 확인한 것만 적는다.
- 구조는 Attendance_iOS의 같은 역할 파일과 대조한 결과를 적는다([프로젝트와 구조](architecture.md)).
- spec은 작업 PR보다 먼저, 또는 같은 PR의 첫 커밋으로 올린다.
