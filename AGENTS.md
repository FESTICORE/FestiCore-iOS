# FestiCore iOS 작업 가이드

현재 FestiCore 코드와 설정을 기준으로 작업한다. 문서의 예시보다 실제 매니페스트와 소스가 우선한다.

## 프로젝트와 구조

- 앱 이름: `FestiCore`; 번들 ID: `io.festiCore.co`; Apple Team ID: `N94CS4N6VR`.
- iOS 18.0 이상, iPhone 대상. Xcode 프로젝트는 Tuist로 생성한다.
- `Projects/App`가 진입점이다. `FeatureAssembly`가 Feature와 Service 조립 모듈을 앱에 연결한다. `Projects/Feature`에는 화면, `Projects/Domain`에는 기능별 계약과 구현, `Projects/Service`에는 API와 세션 등 서비스, `Projects/Core`와 `Projects/UI`에는 공통 모듈을 둔다.
- `Plugins/ProjectTemplatePlugin`은 타깃과 스킴, `DependencyPlugin`은 내부 모듈, `DependencyPackagePlugin`은 외부 패키지 의존성을 정의한다.
- Stage/Prod 구성은 `Config/`와 Tuist 매니페스트를 확인한다. 새로운 모듈은 `Projects/<계층>/<이름>/Project.swift`로 등록한다.
- DesignSystem의 원천 토큰과 생성 자동화는 별도 `FestiCore-DesignSystem` 저장소에서 관리한다. iOS 모듈에 토큰을 임의로 복제하거나 직접 수정하지 않는다.

## 작업 규칙

1. 기존 파일과 모듈 의존성을 먼저 확인한 뒤 수정한다. 다른 작업자의 미커밋 변경은 보존한다.
2. 변경 범위를 좁게 유지하고 기능별 커밋으로 분리한다. 커밋 제목과 본문은 한국어로 작성하고, 제목 끝에 해당 작업 이슈 번호를 `#27`처럼 붙인다.
3. `feature/<작업명>` 브랜치에서 작업하고 PR은 `develop`으로 보낸다. 브랜치 이름과 커밋의 이슈 번호는 구별한다. PR 변경 규모는 2,000줄 이내로 유지한다.
4. 새 라이브러리나 앱 전용 자산을 추가하기 전에 현재 `Tuist/Package.swift`와 관련 모듈을 확인한다. 자격 증명과 로컬 설정을 추적 파일에 넣지 않는다.
5. 변경 후 관련 테스트와 `git diff --check`를 실행하고, 실제로 확인한 범위만 보고한다. `./make test`와 CI의 iOS 시뮬레이터 테스트는 최신 사용 가능 iOS 런타임의 iPhone Duo에서 실행한다. 테스트·CI·실기기 검증은 구별한다.
6. 10분 동안 의미 있는 편집이 없으면 현재 진행 상황과 다음 접근을 사용자에게 알린다.

## TCA와 의존성 주입

- 앱은 `FestiCoreApp`에서 `AppCoordinator` Store를 만들고 `AppCoordinatorView`를 표시한다. 루트 화면 전환은 `AppCoordinator.State`의 enum case와 `store.state` 분기가 담당한다.
- Feature는 `@Reducer`로 상태와 동작을 정의하고 View에는 `StoreOf<Feature>`를 전달한다. 앱이 개별 Feature 구현을 직접 import하지 않도록 `FeatureAssembly`에서 공개한다.
- Point-Free Dependencies를 사용한다. 의존성 인터페이스는 해당 Core·Service·Domain 모듈의 Interface 타깃에, 라이브 구현의 `DependencyKey.liveValue`는 구현 또는 조립 모듈에 둔다. 앱 시작점에서 전역 등록하지 않으며 별도 런타임 DI 컨테이너는 만들지 않는다.
- Feature는 `@Dependency`로 필요한 인터페이스를 사용하고 테스트에서 결정적인 대역을 주입한다. 테스트나 별도 `DependencyValues` 범위에서는 필요한 `register(into:)`를 명시적으로 호출한다. WeaveDI는 사용하지 않는다.

## 통신과 Domain 모듈

- 새 Domain 모듈은 `Interface`와 `Sources`를 나눈다. `Interface/Sources/Entity`에는 공개 값·오류 타입, `Interface/Sources/<기능>`에는 `Sendable` Repository·UseCase의 `*Interface` 계약과 해당 `DependencyKey`·`DependencyValues` 접근자를 둔다. `Sources/<기능>`에는 `*Impl`, `Sources/Model`에는 DTO·Mapper, `Sources`에는 라이브 의존성 등록을 둔다. 테스트·프리뷰 기본값은 명시적인 Mock을 제공하고 미주입 호출은 테스트 이슈로 기록한다.
- Feature는 Domain UseCase Interface를 주입받고, UseCase 구현은 Repository Interface를 사용한다. Repository 구현은 공용 Network·Auth Interface를 주입받는다. 새 클라이언트나 토큰 저장소를 Domain마다 만들지 않는다. 로그인 응답을 검증한 뒤 공용 인증 세션에 저장한다.
- API 경로는 `API`, `FestiCoreDataRequest` 요청은 `APIEndpoint`에 둔다. 요청마다 path, HTTP method, authorization, `Encodable & Sendable` body, 재시도 정책을 명시한다. DTO에서 Entity로의 변환과 도메인 값에서 요청 body로의 변환은 Domain Mapper가 담당한다. APIEndpoint는 Domain이나 Auth Service에 의존하지 않는다.
- 공개 로그인·토큰 갱신은 `.none`, 로그아웃은 `.automatic`을 사용한다. 인증 요청은 응답 DTO를 명시해 `send(_:as:)`로 전송한다. 최종 URL이 `/api/v1/auth/` 로그 본문 보호 규칙과 일치해야 한다. 토큰·인가 코드·비밀 값은 로그와 테스트 실패 메시지에 넣지 않는다.
- 요청의 실제 URL·method·인증·body와 nullable DTO 매핑, 오류 전파, 로그인·로그아웃·갱신의 세션 변경을 테스트한다. `FestiCore.xctestplan`에 새 테스트 타깃을 추가해 CI에서 실행되는지 확인한다. Attendance의 현재 코드 구조를 참고하되 오래된 WeaveDI 문서와 Attendance 전용 API 계약은 복사하지 않는다.

## Claudex Loop

사용자 작업을 시작할 때 설치된 `claudex-loop` 스킬을 읽고 현재 호스트가 Codex인지 Claude인지 확인한다. 계획만 요청받으면 상대 CLI의 계획 검토까지, 구현을 요청받으면 계획 검토와 구현 후 교차 점검까지 수행한다. 검토자·구현자·점검자 세션은 맡은 역할만 수행하며 루프를 다시 시작하지 않는다. 상대 CLI를 사용할 수 없으면 검토가 완료되지 않았다고 명확히 보고한다. 사용자 승인 범위를 그대로 지킨다.

## AI 규칙과 세부 문서

`docs/agent/`의 문서를 작업에 맞게 선택한다. 문서는 경로와 기능이 실제로 존재하는지 확인한 후 적용한다.

| 작업 | 문서 |
| --- | --- |
| 환경·검증 | [개발 환경](docs/agent/development-environment.md), [Git/PR](docs/agent/git-workflow.md) |
| Swift·TCA·DI·네비게이션 | [Swift 규칙](docs/agent/swift-coding-rules.md), [TCA](docs/agent/tca-patterns.md), [DI](docs/agent/dependency-injection.md), [TCAFlow](docs/agent/tcaflow-navigation.md) |
| SwiftUI·팝업 | [SwiftUI](docs/agent/swiftui-patterns.md), [팝업·모달](docs/agent/popup-modal-system.md) |
| 성능 | [성능 점검](docs/agent/ios-performance-optimization.md), [성능 개선](docs/agent/ios-performance-optimizer.md), [PFW 관점](docs/agent/ios-performance-pfw.md), [통합 흐름](docs/agent/performance-integration-guide.md) |
| 테스트 자동화 | [테스트·PR 에이전트](docs/agent/test-auto-pr-agent.md) |

Claude Code의 공유 설정은 `.claude/settings.json`, 커밋 전 검사 훅은 `.claude/hooks/pre-commit-check.sh`에 있다. 개인 권한·기억 파일은 커밋하지 않는다. CLI에 연결된 공유 iOS 스킬은 현재 환경과 작업 범위에 맞을 때만 사용한다.
