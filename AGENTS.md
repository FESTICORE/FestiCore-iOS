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
3. `feature/<작업명>` 브랜치에서 작업하고 PR은 `develop`으로 보낸다. 브랜치 이름과 커밋의 이슈 번호는 구별한다. PR 줄 수 제한은 두지 않는다. 함께 검증할 큰 묶음은 2,000줄을 넘어도 한 PR로 올리고 억지로 쪼개지 않는다. PR 생성 시 작성자 `Roy-wonji`를 담당자로 지정하고 생성 후 할당을 확인한다. 스쿼시 머지할 때 최종 커밋 제목과 본문을 직접 지정한다. 본문에는 필요한 변경 요약만 남기고 GitHub가 자동으로 채운 개별 커밋 내역은 삭제한다. 머지 후 실제 커밋 메시지를 확인한다.
4. 새 라이브러리나 앱 전용 자산을 추가하기 전에 현재 `Tuist/Package.swift`와 관련 모듈을 확인한다. 자격 증명과 로컬 설정을 추적 파일에 넣지 않는다.
5. 변경 후 관련 테스트와 `git diff --check`를 실행하고, 실제로 확인한 범위만 보고한다. `./make test`와 CI의 iOS 시뮬레이터 테스트는 최신 사용 가능 iOS 런타임의 iPhone Duo에서 실행한다. 테스트·CI·실기기 검증은 구별한다.
6. 10분 동안 의미 있는 편집이 없으면 현재 진행 상황과 다음 접근을 사용자에게 알린다.
7. API·Domain·Reducer·View·테스트의 값을 반환하는 Swift 일반 함수와 계산 속성에는 `return`을 명시한다. `Void`·초기화·결과 빌더는 Swift 문법을 따른다.
8. Swift 함수와 이니셜라이저 선언의 파라미터가 2개 이상이면 여는 괄호 다음 줄부터 파라미터를 하나씩 각 줄에 쓴다. 파라미터가 0~1개면 한 줄 선언도 허용한다.
9. 함수와 이니셜라이저 호출의 인자가 2개 이상이면 여는 괄호 다음 줄부터 각 인자를 별도 줄에 쓴다. `switch`의 `case` 패턴 매칭은 한 줄로 써도 된다.

## TCA와 의존성 주입

- 앱은 `FestiCoreApp`에서 `AppCoordinator` Store를 만들고 `AppCoordinatorView`를 표시한다. 루트 화면 전환은 `AppCoordinator.State`의 enum case와 `store.state` 분기가 담당한다.
- 앱 호스팅 단위 테스트에서는 루트 Store의 자동 시작 효과를 실행하지 않는다. 테스트 기본 Mock의 미등록 이슈를 무음 처리해 실패를 숨기지 말고, 개별 테스트에 필요한 의존성을 명시적으로 주입한다.
- Feature는 `@Reducer`로 상태와 동작을 정의하고 View에는 `StoreOf<Feature>`를 전달한다. 앱이 개별 Feature 구현을 직접 import하지 않도록 `FeatureAssembly`에서 공개한다.
- Point-Free Dependencies를 사용한다. 의존성 인터페이스는 해당 Core·Service·Domain 모듈의 Interface 타깃에, 라이브 구현의 `DependencyKey.liveValue`는 구현 또는 조립 모듈에 둔다. 앱 시작점에서 전역 등록하지 않으며 별도 런타임 DI 컨테이너는 만들지 않는다.
- Feature는 `@Dependency`로 필요한 인터페이스를 사용하고 테스트에서 결정적인 대역을 주입한다. 테스트나 별도 `DependencyValues` 범위에서는 필요한 `register(into:)`를 명시적으로 호출한다. WeaveDI는 사용하지 않는다.
- 리듀서는 `view`·`async`·`inner`·`delegate` 액션과 `extension`의 `handle*Action` 함수로 나눠 쓴다. 한 화면에는 리듀서 하나를 두고, Feature는 Domain UseCase와 시스템 의존성만 주입한다. 자세한 규칙은 [TCA](docs/agent/tca-patterns.md).
- `State` 저장 속성이 많아지면 같은 화면 책임으로 함께 변하는 값을 하위 상태나 표시 Model로 묶는다. 공개 업무 값은 Domain Entity에 두고, 상태 이동 후 전이·취소·재시도 테스트를 확인한다.
- 유한한 단계와 상호 배타적인 선택은 문자열·불리언 조합 대신 enum으로 표현한다.

## SwiftUI View 구성

- 앱·Feature·Widget·DesignKit·SharedUI의 SwiftUI View에 같은 규칙을 적용한다. 타입 본문에는 저장 속성, 초기화, `body`를 두고, 화면 섹션·하위 뷰 빌더·UI 전용 헬퍼는 같은 파일의 `private extension <View이름>`으로 분리한다. 테스트에서 접근하는 내부 헬퍼가 함께 있으면 일반 `extension`에서 각 비공개 멤버에 `private`를 붙인다. 외부에서 호출하는 체이닝 설정은 기존 `public extension`에 둔다. DesignKit·SharedUI 컴포넌트의 이니셜라이저에는 필수 내용만 두고 스타일·상태·옵션은 `public extension`의 `func x(_:) -> Self` 체이닝 설정으로 둔다. 아직 이니셜라이저 옵션으로 남은 기존 컴포넌트는 [SwiftUI](docs/agent/swiftui-patterns.md)에 이전 대상으로 적었으며 본보기로 삼지 않는다. 분리할 내용이 없는 작은 View에 빈 extension을 만들지 않는다.
- 단일 View 조각은 계산 `var ...: some View`로 두고, 여러 View를 묶거나 분기하는 섹션은 `@ViewBuilder func ... -> some View`로 분리한다. 일반 계산 속성과 함수에는 명시적 `return`을 사용하되 결과 빌더는 Swift 문법을 따른다.
- 화면 View는 `@ViewAction`을 붙이고 store 하나만 받는다. 확인 팝업은 SharedUI `Alert/`의 `fcAlert`, 바텀시트는 SharedUI `Modal/`의 `fcModal`로 띄운다. 자세한 규칙은 [SwiftUI](docs/agent/swiftui-patterns.md), [팝업·모달](docs/agent/popup-modal-system.md).
- View 분리는 상태 전환, TCA 액션, 접근성, 다크 모드와 화면 동작을 바꾸지 않는 범위에서 한다. 여러 화면이 실제로 공유하는 컴포넌트만 공용 UI 모듈로 이동한다.
- 비동기 데이터를 기다리는 화면은 로딩·실패·빈 상태를 구분하고 공용 Skeleton을 사용한다. 데이터가 비었다는 이유만으로 로딩을 계속 표시하지 않는다.

## 통신과 Domain 모듈

- 디자인(DesignExports·Figma 시안)과 API 연동은 보류하지 않는다. 필요한 API가 없으면 개발 환경 백엔드에 만들고 iOS Domain·Feature까지 연동한다. 운영 DB 변경·운영 배포·라이선스 승인만 사람의 승인을 기다린다.
- 모든 구조(모듈·폴더·파일 이름·코디네이터·테스트 배치)와 API·DI·UseCase·Repository의 배치와 주입은 Attendance_iOS(`DDD-Community/Attendance_iOS`, 로컬 `~/Desktop/SideProject/Attendance/Attendance_iOS`, 읽기 전용)를 따른다. 파일을 만들기 전에 Attendance `Projects/Domain/AttendanceDomain`, `Projects/Service/{API,APIEndpoint}`의 같은 역할 파일을 열어 대조한다.
- 새 Domain 모듈은 `Interface`와 `Sources`를 나눈다. `Interface/Sources/Entity`에는 공개 값·오류 타입, `Interface/Sources/<기능>`에는 `Sendable` Repository·UseCase의 `*Interface` 계약, Mock, `TestDependencyKey`·`DependencyValues` 접근자, `Interface/Sources/Exported`에는 재공개 import를 둔다. `Sources/<기능>`에는 `<X>UseCaseImpl`, `Sources/Repository`에는 `<X>RepositoryImpl`, `Sources/Model/DTO`·`Sources/Model/Mapper`에는 DTO·Mapper, `Sources/<X>LiveDependencies.swift`에는 `liveValue` 등록, `Sources/Exported`에는 재공개 import를 둔다. 테스트·프리뷰 기본값은 명시적인 Mock을 제공하고 미주입 호출은 테스트 이슈로 기록한다.
- Domain Repository·UseCase 계약과 구현 타입 위에는 역할과 경계를 설명하는 한두 줄의 `///` 문서 주석을 단다.
- 기능 단위로 Domain 모듈(예: `TimetableDomain`)을 두고, Feature가 쓰는 공개 값 타입은 Feature `Model`이 아니라 Domain `Interface/Sources/Entity`에 둔다. 자세한 규칙은 [Domain 모듈](docs/agent/domain-modules.md).
- Feature는 Domain UseCase Interface를 주입받고, UseCase 구현은 Repository Interface를 사용한다. Repository 구현은 공용 Network·Auth Interface를 주입받으며, 그 밖에 주입할 수 있는 범위는 [Domain 모듈](docs/agent/domain-modules.md)의 RepositoryImpl 주입 범위 한 곳에 정한다. 새 클라이언트나 토큰 저장소를 Domain마다 만들지 않는다. 로그인 응답을 검증한 뒤 공용 인증 세션에 저장한다.
- API 경로는 `API`, `FestiCoreDataRequest` 요청은 `APIEndpoint`에 둔다. 요청마다 path, HTTP method, authorization, `Encodable & Sendable` body, 재시도 정책을 명시한다. DTO에서 Entity로의 변환과 도메인 값에서 요청 body로의 변환은 Domain Mapper가 담당한다. APIEndpoint는 Domain이나 Auth Service에 의존하지 않는다.
- 공개 로그인·토큰 갱신은 `.none`, 로그아웃은 `.automatic`을 사용한다. 인증 요청은 응답 DTO를 명시해 `send(_:as:)`로 전송한다. 최종 URL이 `/api/v1/auth/` 로그 본문 보호 규칙과 일치해야 한다. 토큰·인가 코드·비밀 값은 로그와 테스트 실패 메시지에 넣지 않는다.
- 요청의 실제 URL·method·인증·body와 nullable DTO 매핑, 오류 전파, 로그인·로그아웃·갱신의 세션 변경을 테스트한다. `FestiCore.xctestplan`에 새 테스트 타깃을 추가해 CI에서 실행되는지 확인한다. 오래된 WeaveDI 문서나 다른 앱 전용 API 계약은 복사하지 않는다.
- HTTP와 WebSocket은 `Projects/Core/FestiCoreNetwork`의 Alamofire 구조(`SessionFactory`의 Session, `NetworkClient`, `AuthorizingInterceptor`·`FestiCoreAuthenticator`, `FestiCoreEventMonitor`·`NetworkLogRedactor`, `FestiCoreEndpoint` 재시도 정책) 안에 둔다. WebSocket도 같은 Session·인터셉터·EventMonitor·로그 보호·재시도 정책 체계를 공유하고, 호출부는 HTTP 요청과 같은 체이닝·async 방식으로 쓴다. 재시도에서 연결 재접속과 메시지 재전송을 구분하고 멱등하지 않은 메시지는 자동 재전송하지 않는다. WebSocket 이전은 끝났다. `NetworkClientFactory.webSocket()`의 `NetworkClient`가 `FestiCoreWebSocketRequest`로 `Session.webSocketRequest`를 연다(`Sources/WebSocket/WebSocketConnection`·`WebSocketHandshakeInterceptor`). 이 구조 밖에 새 통신 코드를 만들지 않는다.
- 앱 내부 DB(로컬 캐시·저장)는 SQLiteData로 쓰고 Attendance `DDDStorage`와 같은 `Projects/Core/FestiCoreStorage` 구성을 거친다. DB는 `Interface/Database/AppDatabaseDependency`·`Sources/Shared/AppDatabaseMigrator`, 단순 값은 `Interface/Shared/PersistentSharedKey`·`Sources/Shared/SQLiteSharedValueStorage`, 조립은 `Sources/Factory/StorageFactory`·`Sources/DependencyValues+Storage`가 맡는다. 단순 값은 Attendance `AuthDomain/Interface/Sources/Entity/UserSessionSharedKey`처럼 `PersistentSharedKey`로 선언해 `@Shared`로 쓰고, 레코드는 Attendance `ScheduleDomain/Sources/Repository/Local/ScheduleLocalDataSource`처럼 `Sources/Repository/Local/<X>LocalDataSource`에서 `@Dependency(\.appDatabase)`로 저장한다.
- 레코드·계정별 데이터의 이전은 Attendance `DDDStorage`와 같게 배치한다. 이전 코드는 `FestiCoreStorage/Sources/Legacy/LegacyUserDefaultsMigration`(Attendance `Sources/Legacy/LegacySwiftDataMigration`)에 두고, `Sources/Factory/StorageFactory`의 `prepareDatabase`에 `importLegacy` 훅(Attendance `prepareDatabase(importLegacy:)`)을 더해 `AppDatabaseMigrator` 다음에 실행한다. 레코드 표와 이전 기록 표(Attendance `legacyCacheImport`)는 `AppDatabaseMigrator`에서 만든다. 한 이전 단위의 레코드 쓰기와 완료·소유 계정 기록은 Attendance처럼 `database.write` 한 트랜잭션에서 하고 시작할 때 완료 기록을 확인해 건너뛴다. 실패하면 트랜잭션이 되돌아가 완료 기록이 남지 않으므로 다음 실행에서 다시 시도하며, 실패는 로그만 남기고 현재 DB를 메모리 DB로 바꾸지 않는다. 이전된 레코드의 계정 소유 확인은 `Interface/Database/LegacyCacheAccess`처럼 `isAllowed`·`markRefreshed`로 하고, LocalDataSource가 Attendance `ScheduleLocalDataSource`·`ProfileLocalDataSource`처럼 읽을 때 소유자가 현재 세션과 같은지 확인하고 서버 값으로 새로 저장한 뒤 소유 표시를 지운다.
- `FestivalDomain/Sources`의 UserDefaults 저장소 다섯 개(`Bookmark/FestivalBookedStore+Live`, `Guide/FestivalGuideVisibilityStore+Live`, `PackDetail/FestivalPackLocalStore+Live`, `RecentSearch/FestivalRecentSearchStore+Live`, `Selection/FestivalSelectionStore+Live`)는 SQLiteData로 옮길 대상이다. 단순 값(`FestiCore.selectedFestivalID`, `FestiCore.hiddenFollowedFlagGuides`, `FestiCore.pack.autoDownloadOnWiFi`)은 `PersistentSharedKey`의 `legacyData`로 넘긴다. 레코드는 위 `LegacyUserDefaultsMigration`과 LocalDataSource로 옮긴다: `FestivalBookedStore`의 계정별 목록(`FestiCore.bookedFestivalIDs.user.<계정>`)과 계정별 이전 상태(소유자 없는 `legacyKey` 목록, `migrationOwnerKey`·`migrationDecisionKey`, `FestiCore.bookedFestivalIDs.eligible.<계정>`), `FestivalPackLocalStore`의 축제별 체크리스트(`FestiCore.pack.checklist.<축제>`), `FestivalRecentSearchStore`의 계정별·익명 목록(`FestiCore.festivalRecentSearches.user.<계정>`·`.anonymous`). 계정별 레코드는 소유 계정을 함께 옮긴다. `legacyKey` 목록은 지금 동작대로 결정 전에는 제안 대상으로 남기고, `migrationDecisionKey`가 `accepted`면 `migrationOwnerKey` 계정의 목록에 합치며, `declined`면 옮기지 않는다. 중복 실행·부분 실패·기존 값 없음에서도 결과가 같게 하고, 완료 기록과 보존 테스트를 확인한 뒤에만 원본 UserDefaults 키를 지운다. `FestiCoreStorage/Sources/Onboarding/FirstInstallOnboardingFileStore`는 Selection·Bookmark·RecentSearch 저장소의 키(`FestiCore.selectedFestivalID`, `FestiCore.bookedFestivalIDs*`, `FestiCore.festivalRecentSearches*`)로 업그레이드 사용자를 판별하므로, 이 키를 지우기 전에 이 판별을 이전된 DB 데이터나 이전 완료 표식 확인으로 바꾸고 완료 영수증 없는 업그레이드 사용자가 첫 설치 온보딩으로 가지 않는지 테스트한다.
- Sentry·Mixpanel 코드(초기화·이벤트·화면 추적·성능 추적·오류 보고)는 `Projects/Service/FestiCoreAnalytics`에 두고, Picke-iOS(`SWYP-Find/Picke-iOS`) `Projects/Service/PickeAnalytics/Sources`의 `Configuration/SentryConfiguration`·`MixpanelConfiguration`, `UseCase/AnalyticsUseCase+Live`, `Trace/PickeTracedView`와 같은 구조·호출 방식으로 쓴다.
- 표시되는 푸시는 `mutable-content`로 `Projects/Extension/FestiCoreNotificationService`를 거쳐 내용 보강과 App Group 데이터 갱신을 한다. 지금 `Extension/NotificationService.swift`는 `contentHandler(request.content)`만 부르는 통과 구현이므로 보강과 App Group 갱신을 구현할 대상이다. 앱을 깨워 동기화할 때는 `content-available` 무음 푸시를 쓰고 앱의 원격 알림 처리 경로(`AppDelegate`)에서 처리한다.
- 딥링크는 Picke-iOS 구조를 FestiCore 위치에 그대로 둔다. `Core/PickeCoreUtility/Sources/Deeplink/PickeDeeplink`는 `Projects/Core/FestiCoreUtility/Sources/Deeplink/FestiCoreDeeplink`, `App/Sources/Deeplink/PendingDeeplinkStore`·`AppDeeplinkBridge`는 `Projects/App/Sources/Deeplink/`의 같은 이름, 대기 저장소의 `@Shared(.pendingDeeplink)` 키인 `Core/PickeStorage/Interface/Shared/PendingDeeplinkSharedKey`(`PersistentSharedKey`)는 `Projects/Core/FestiCoreStorage/Interface/Shared/PendingDeeplinkSharedKey`, URL 진입점인 `App/Sources/Application/PickeApp`의 `onOpenURL`→`AppDeeplinkBridge.handleURL(url)`은 `Projects/App/Sources/Application/FestiCoreApp`의 `onOpenURL`→`AppDeeplinkBridge.handleURL(url)`, 알림 탭을 받는 `App/Sources/Application/AppDelegate+Push`는 `Projects/App/Sources/Application/AppDelegate+Push`, `AppReducer`의 딥링크 처리(`AppDeeplinkBridge.consumePending()`)는 루트 `AppCoordinator`(`Projects/App/Sources/Navigation/Main/AppCoordinator`)의 라우팅에 대응한다. Picke 키의 `legacyData`는 이전 저장소 값을 넘기기 위한 것이므로, 대기 값을 영속 저장한 적이 없는 FestiCore 키에는 두지 않는다. 경로는 `FestiCoreDeeplink` enum 하나로 정의하고 파싱·대기·라우팅 책임을 나누며 경로별로 테스트한다. 이전 대상: App 전용 경로 enum인 `Projects/App/Sources/Navigation/Main/WidgetDeepLink.swift`는 `FestiCoreDeeplink`로 합치고, `FestiCoreApp.swift`의 `RootView`가 View 상태로 대기·라우팅하는 `@State private var pendingWidgetRoute: WidgetDeepLink?`와 `openPendingWidgetRouteIfReady()`는 대기를 `PendingDeeplinkStore`, URL 전달을 `AppDeeplinkBridge`, 홈 준비 후 꺼내 이동하기를 `AppCoordinator`로 옮긴다.

## Claudex Loop

사용자 작업을 시작할 때 설치된 `claudex-loop` 스킬을 읽고 현재 호스트가 Codex인지 Claude인지 확인한다. 계획만 요청받으면 상대 CLI의 계획 검토까지, 구현을 요청받으면 계획 검토와 구현 후 교차 점검까지 수행한다. 검토자·구현자·점검자 세션은 맡은 역할만 수행하며 루프를 다시 시작하지 않는다. 상대 CLI를 사용할 수 없으면 검토가 완료되지 않았다고 명확히 보고한다. 사용자 승인 범위를 그대로 지킨다.

## AI 규칙과 세부 문서

`docs/agent/`의 문서를 작업에 맞게 선택한다. 문서는 경로와 기능이 실제로 존재하는지 확인한 후 적용한다.

| 작업 | 문서 |
| --- | --- |
| 환경·검증 | [개발 환경](docs/agent/development-environment.md), [Git/PR](docs/agent/git-workflow.md) |
| Swift·TCA·DI·네비게이션 | [Swift 규칙](docs/agent/swift-coding-rules.md), [TCA](docs/agent/tca-patterns.md), [DI](docs/agent/dependency-injection.md), [Domain 모듈](docs/agent/domain-modules.md), [TCAFlow](docs/agent/tcaflow-navigation.md) |
| SwiftUI·팝업·디자인 | [SwiftUI](docs/agent/swiftui-patterns.md), [팝업·모달](docs/agent/popup-modal-system.md), [Figma 대조](docs/agent/figma-design.md) |
| 성능 | [성능 점검](docs/agent/ios-performance-optimization.md), [성능 개선](docs/agent/ios-performance-optimizer.md), [PFW 관점](docs/agent/ios-performance-pfw.md), [통합 흐름](docs/agent/performance-integration-guide.md) |
| 테스트 자동화 | [테스트·PR 에이전트](docs/agent/test-auto-pr-agent.md) |

Claude Code의 공유 설정은 `.claude/settings.json`, 커밋 전 검사 훅은 `.claude/hooks/pre-commit-check.sh`에 있다. 개인 권한·기억 파일은 커밋하지 않는다. CLI에 연결된 공유 iOS 스킬은 현재 환경과 작업 범위에 맞을 때만 사용한다.
