# FestiCore iOS

페스티벌 앱 FestiCore의 iOS 저장소. 앱 `FestiCore`(번들 ID `io.festiCore.co`, Team ID `N94CS4N6VR`), iOS 18.0 이상 iPhone 대상이다.

이 파일은 색인이다. 세부 규칙은 아래 문서에 있고, 작업에 해당하는 문서만 읽는다. 현재 코드와 설정을 기준으로 작업하며, 문서의 예시보다 실제 매니페스트와 소스가 우선한다.

## 스택

| 영역 | 기술 | 빌드 |
| --- | --- | --- |
| 앱 | Swift 6 · SwiftUI · TCA · TCAFlow · Point-Free Dependencies | Tuist 4 (`.mise.toml` 고정) |
| 통신 · 저장 | Alamofire(`FestiCoreNetwork`) · SQLiteData(`FestiCoreStorage`) | Tuist SPM (`Tuist/Package.swift`) |
| 관측 | Sentry(오류) · Mixpanel(행동) | `Service/FestiCoreAnalytics`에서만 |

환경은 Stage · Prod 두 개다(`Config/`).

## 저장소 구조

```
Projects/
  App/        진입점 (FestiCoreApp → AppCoordinator, Navigation Coordinator)
  Feature/    화면 (FeatureAssembly가 앱에 연결)
  Domain/     기능별 계약(Interface)과 구현(Sources)
  Service/    API · APIEndpoint · 인증 · 분석 등 서비스 (ServiceAssembly)
  Core/       Network · Storage · Utility 등 공통 (CoreAssembly)
  UI/         DesignKit · SharedUI · DesignSystem 등
  Widget/ · Extension/   위젯 · 알림 서비스 확장
Plugins/      ProjectTemplatePlugin · DependencyPlugin · DependencyPackagePlugin
Tuist/        Package.swift · 템플릿
.claude/      에이전트 규칙 · 문서 · 스킬 · 훅
docs/         사람이 읽는 설계 문서
```

자세한 구조와 의존 방향은 `.claude/docs/architecture.md`에 있다.

## 문서 색인

| 작업 | 먼저 읽을 문서 |
| --- | --- |
| 이슈 · 브랜치 · 커밋 · PR · 스쿼시 머지 | `.claude/docs/git-workflow.md` |
| 환경 · 명령 · 라이브러리 추가 · 검증 범위 | `.claude/docs/development-environment.md` · 스킬 `tuist` |
| 모듈 추가 · 의존 방향 · 기준 저장소 | `.claude/docs/architecture.md` · 스킬 `tuist` |
| Swift 함수 · `return` · 인자 줄바꿈 | `.claude/docs/code-convention.md` |
| 화면 · Reducer | `.claude/docs/ios-tca.md` · 스킬 `tca-feature` |
| 화면 전환 (AppCoordinator · TCAFlow) | `.claude/docs/navigation.md` · 스킬 `screen-flow` |
| 의존성 등록 · 테스트 대역 | `.claude/docs/dependency-injection.md` |
| Domain 모듈 · API · APIEndpoint · Network | `.claude/docs/domain-modules.md` |
| 로컬 저장소 (SQLiteData · `@Shared` · 레거시 이전) | `.claude/docs/storage.md` |
| 분석 (Sentry · Mixpanel) | `.claude/docs/analytics.md` |
| 푸시 · 알림 서비스 확장 · 딥링크 | `.claude/docs/push-deeplink.md` |
| SwiftUI View | `.claude/docs/swiftui-patterns.md` · 스킬 `swiftui-pro` |
| 팝업 · 바텀시트 | `.claude/docs/popup-modal-system.md` |
| Figma 대조 | `.claude/docs/figma-design.md` |
| 동시성 | 스킬 `swift-concurrency-pro` |
| 테스트 작성 | `.claude/docs/test-auto-pr-agent.md` · 스킬 `swift-testing-pro` |
| 성능 | `.claude/docs/performance-integration-guide.md` (점검 · 개선 · PFW 관점 문서로 이어짐) |
| 기능 spec · 설계 문서 | `.claude/docs/spec-guide.md` · 스킬 `spec-first` → 모듈 `.spec/` · `.claude/docs/specs/` |
| 에이전트 · 훅 · 검증 게이트 | `.claude/docs/harness.md` |
| 동작 설명으로 코드 찾기 (로컬 의미 검색) | `.claude/docs/code-search.md` · 스킬 `code-search` |

문서는 경로와 기능이 실제로 존재하는지 확인한 후 적용한다.

경로별 규칙은 `.claude/rules/`에 있다(`app` · `feature` · `domain` · `service-core` · `ui`). 해당 경로의 파일을 다룰 때 자동으로 적용된다.

## 반드시 지킬 규칙 (Hard)

1. 모든 작업은 이슈에서 시작한다. 브랜치는 `feature/<작업명>`, PR 대상은 `develop`이다. 브랜치 이름과 커밋의 이슈 번호는 구별한다.
2. `develop` · `main`에 직접 커밋하거나 푸시하지 않는다. 훅이 막는다.
3. 커밋 제목과 본문은 한국어로 쓰고 제목 끝에 해당 작업 이슈 번호를 `#27`처럼 붙인다. 메시지에 `Co-Authored-By`를 넣지 않는다. 훅이 검사한다.
4. PR을 만들 때 작성자 `Roy-wonji`를 담당자로 지정하고 생성 후 할당을 확인한다.
5. 스쿼시 머지 커밋은 제목 한 줄(PR 제목 + ` (#PR번호)`)만 남기고 본문은 비운다. 머지하며 원격 · 로컬 브랜치를 지우고, 머지 후 실제 커밋 메시지를 확인한다.
6. 코드를 바꿨으면 `.claude/scripts/verify`를 통과한 뒤 커밋한다. 통과 기록 없이 커밋하면 훅이 막는다.
7. 검증하지 않은 결과를 완료로 보고하지 않는다. 테스트 · CI · 실기기 검증을 구별하고 실제로 확인한 범위만 보고한다.
8. 자격 증명과 로컬 설정(`GoogleService-Info.plist` 등)을 추적 파일에 넣지 않는다. 토큰 · 인가 코드 · 비밀 값은 로그와 테스트 실패 메시지에 넣지 않는다.
9. 운영 DB 변경 · 운영 배포 · 라이선스 승인만 사람의 승인을 기다린다. 디자인과 API 연동은 보류하지 않는다.
10. 모든 구조와 API · DI · UseCase · Repository의 배치와 주입은 Attendance_iOS(읽기 전용)를 따른다. 파일을 만들기 전에 같은 역할 파일을 열어 대조한다.
11. 같은 단계가 2번 연속 실패하면 멈추고 시도한 내용과 실패 원인을 사용자에게 보고한다. 승인 없이 세 번째 시도를 하지 않는다.
12. DesignSystem 토큰 원천은 `FestiCore-DesignSystem` 저장소다. iOS 모듈에 토큰을 복제하거나 직접 고치지 않는다.

## 명령

```bash
./make help        # 지원 명령과 인자
./make setup       # mise 설치, 의존성 · 로컬 Tuist 캐시 준비, 프로젝트 생성
./make generate    # FestiCore.xcworkspace 생성
./make build       # Stage 시뮬레이터 빌드
./make test        # Stage 플랜 전체 테스트
./make module <Layer> <Name>     # 모듈 생성
.claude/scripts/verify           # 바뀐 경로에 맞는 커밋 전 검증
```

`.xcodeproj` · `.xcworkspace`는 Tuist 생성물이다. 새 파일을 만들면 `./make generate`로 다시 생성한다.

## 문서 갱신

규칙을 바꾸면 같은 PR에서 해당 문서와 훅을 고친다. `AGENTS.md`에는 규칙을 다시 쓰지 않는다. 이 파일은 200줄 아래로 유지한다.
