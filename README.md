# FestiCore iOS

<div align="center">

<img width="150" alt="FestiCore 앱 아이콘" src="Projects/App/Resources/Assets.xcassets/AppIcon.appiconset/FestiCore-AppIcon-1024.png">

**축제를 위한 FestiCore iOS 앱**

![Platform](https://img.shields.io/badge/Platform-iOS-orange.svg)
![Swift](https://img.shields.io/badge/Swift-6-FA7343.svg?logo=swift&logoColor=white)
![iOS](https://img.shields.io/badge/iOS-18.0+-34C759.svg)
![Architecture](https://img.shields.io/badge/Architecture-TCA-purple.svg)
![Tuist](https://img.shields.io/badge/Tuist-4.206.0-blue.svg)

[아키텍처](#아키텍처) · [빠른 시작](#빠른-시작) · [개발 명령어](#개발-명령어) · [개발 가이드](#개발-가이드)

</div>

## 프로젝트

FestiCore는 축제를 위한 iOS 앱입니다. Festival 모듈에서 축제 목록을 조회하고, 축제를 선택하면 공개 팩을 받아 저장합니다. 저장된 목록과 팩은 앱 재시작 후 네트워크 없이 다시 볼 수 있습니다. Live Activity의 화면상 시작 동작은 구현됐으며, 잠금 화면 표시는 실제 기기에서 검증 중입니다.

현재 구성:

- Stage·Prod 앱, Splash에서 탭과 축제 목록·라이브 보드로 이어지는 TCA 화면 전환
- 네트워크·인증·저장소·로깅의 모듈 경계와 의존성 조립
- APNs 토큰의 Keychain 보관과 앱 실행 시 기기 등록
- 공개 축제 목록의 마지막 정상 응답 저장, 팩 WebSocket 동기화와 오프라인 복구
- 코드 기반 색상, base·point Pretendard 타이포그래피, 공통 UI
- ActivityKit 공유 모델과 독립 WidgetKit 확장
- Swift Testing, Tuist 프로젝트 생성 및 PR CI

## 스크린샷

제품 화면 캡처는 화면이 완성되고 실제 기기에서 확인한 뒤 추가합니다.

## 아키텍처

SwiftUI와 The Composable Architecture를 사용하는 Tuist 멀티모듈 프로젝트입니다. `Workspace.swift`가 `Projects/**`를 모으고, `AppCoordinator`는 Splash에서 `MainTabCoordinator`로 전환합니다. 축제 목록과 라이브 보드는 `FestivalCoordinator`가 TCAFlow 경로로 관리합니다.

### 폴더 구조

~~~text
Projects/
├── App/                           # 앱 진입점, 설정, 테스트 플랜
├── Feature/
│   ├── FeatureAssembly/           # 화면 모듈 조립
│   ├── Festival/                  # 축제 목록·라이브 보드, Client·Store·UseCase
│   ├── Login/                     # 로그인 Feature
│   └── Timetable/                 # 선택한 축제의 공연 시간표
├── Domain/
│   ├── AuthDomain/                # 인증 Entity·Repository·UseCase
│   └── FestivalDomain/            # 축제 목록 계약과 모델
├── Service/
│   ├── API/                      # API 요청 인터페이스
│   ├── APIEndpoint/              # API 경로·인증 정책
│   ├── ServiceAssembly/           # 서비스 의존성 조립
│   ├── FestiCoreAuth/             # 인증 세션과 토큰 갱신
│   ├── FestiCoreAnalytics/        # Mixpanel·Sentry 초기화
│   ├── FestiCoreConfig/           # Firebase 앱 설정
│   ├── FestiCoreDevice/           # 기기·Live Activity 등록
│   ├── FestiCoreFestivalCatalog/  # 축제 목록과 로컬 캐시
│   └── FestiCorePack/             # 축제 팩 동기화와 로컬 캐시
├── Core/
│   ├── CoreAssembly/              # Core 구현 조립
│   ├── FestiCoreNetwork/          # HTTP 클라이언트
│   ├── FestiCoreStorage/          # Keychain과 저장소
│   └── FestiCoreLogger/           # 공통 로깅
├── UI/
│   ├── FestiCoreDesignKit/        # 디자인 토큰과 리소스
│   ├── FestiCoreSharedUI/         # 공통 UI
│   ├── FestiCoreAnimation/        # 애니메이션 표시 API
│   └── FestiCoreLiveActivity/     # 앱·위젯 공유 ActivityKit 타입
├── Extension/
│   └── FestiCoreNotificationService/ # 푸시 알림 서비스 확장
└── Widget/
    └── FestiCoreWidget/           # 잠금 화면·Dynamic Island 확장
~~~

각 폴더는 추적 중인 `Project.swift` 기준입니다. 생성물과 아직 프로젝트에 등록되지 않은 실험 폴더는 제외했습니다.

### Mermaid 의존성 흐름

~~~mermaid
flowchart TD
    App --> FeatureAssembly
    App --> ServiceAssembly
    App --> CoreAssembly
    FeatureAssembly --> Festival
    FeatureAssembly --> Login
    FeatureAssembly --> Timetable
    FeatureAssembly --> AuthDomain
    FeatureAssembly --> ServiceAssembly
    Festival --> FestivalDomainInterface["FestivalDomain / Interface"]
    Festival --> PackInterface["FestiCorePack / Interface"]
    Festival --> SharedUI["FestiCoreSharedUI"]
    Login --> AuthDomainInterface["AuthDomain / Interface"]
    AuthDomain --> AuthDomainInterface
    AuthDomain --> AuthInterface["FestiCoreAuth / Interface"]
    AuthDomain --> APIEndpoint
    AuthDomain --> NetworkInterface["FestiCoreNetwork / Interface"]
    ServiceAssembly --> CoreAssembly
    ServiceAssembly --> FestivalDomainInterface
    ServiceAssembly --> Network["FestiCoreNetwork / Implementation"]
    ServiceAssembly --> Services["Auth · Device · FestivalCatalog · Pack"]
    CoreAssembly --> Core["Logger · Network · Storage"]
    APIEndpoint --> NetworkInterface
    App -. 포함 .-> Widget["FestiCoreWidget"]
    App -. 포함 .-> Notification["FestiCoreNotificationService"]
~~~

- `FeatureAssembly`는 Festival·Login·Timetable과 인증 도메인, `ServiceAssembly`를 연결합니다.
- 화면은 필요한 도메인·서비스의 Interface를 직접 의존하고, `ServiceAssembly`와 `CoreAssembly`가 라이브 구현을 조립합니다.
- App은 Feature·Service·Core 조립 모듈과 앱에서 직접 사용하는 UI·설정 모듈을 참조합니다. 위젯과 알림 서비스는 앱에 포함되는 별도 타깃입니다.

### 모듈 그래프

`./make graph`와 `./make graph:prod`는 현재 Tuist 프로젝트에서 전체·제품 모듈 그래프를 생성합니다. 생성 방법은 [아키텍처 문서](docs/architecture/README.md)를 참고하세요.

### TCA 화면 흐름

`AppCoordinator`는 Splash가 끝나면 `MainTabCoordinator`를 표시합니다. `FestivalCoordinator`의 첫 경로는 축제 목록이며, 축제를 선택하면 라이브 보드 경로를 추가합니다. 목록과 라이브 보드의 상태는 `FestivalFeature`가 관리합니다. `MainTabCoordinator`는 선택한 축제 팩의 시간표를 Timetable 탭에 전달합니다.

`FestivalFeature.State.catalog`는 `IdentifiedArrayOf<FestivalCatalogItem>`을 사용합니다. `FestivalCatalogUseCase`는 중복 축제와 초기 선택을 처리하고, `FestivalImageUseCase`는 이미지 수집·프리페치 대상을 정리합니다. 두 유스케이스는 `Projects/Feature/Festival/Sources/Common/UseCase/`에 있습니다.

라이브 보드는 `FestivalLiveBoardService` 계약을 Domain에 두고, Service의 `NetworkFestivalLiveBoardService`가 축제별 라이브 상태와 공개 깃발 프로필을 조회합니다. 화면이 열려 있고 앱이 활성 상태일 때 35초 간격으로 갱신하며, 화면을 닫거나 앱이 백그라운드로 가면 갱신을 중단합니다. 기기 등록 ID는 기존 `DeviceRegistrationService`에서 읽습니다.

### 의존성 주입

Point-Free Dependencies를 사용합니다. `ServiceAssembly`가 네트워크·인증 세션을 같은 수명주기로 조립하고, 각 기능 모듈은 자신의 `DependencyKey.liveValue`를 등록합니다. `AuthDomain`은 공용 세션을 `@Dependency`로 받아 API를 호출합니다. 앱 시작점의 별도 전역 등록이나 런타임 DI 컨테이너는 사용하지 않습니다.

화면 Reducer는 Interface만 import해 `@Dependency(\.authUseCase)`로 유스케이스를 받고, 테스트는 `TestStore`나 `withDependencies`에서 해당 값을 대역으로 교체합니다. 모듈별 경계와 테스트 규칙은 [의존성 주입 문서](docs/agent/dependency-injection.md)를 참고하세요.

## 기술 스택

| 영역 | 기술 |
| --- | --- |
| 언어·UI | Swift 6, SwiftUI |
| 상태 관리·내비게이션 | The Composable Architecture, TCAFlow |
| 프로젝트 | Tuist 4.206.0, Mise |
| 의존성 주입 | Point-Free Dependencies |
| 네트워크·저장소 | Alamofire, Keychain |
| 디자인·이미지 | FestiCoreDesignKit, Pretendard, Kingfisher 패키지 |
| Live Activity | ActivityKit, WidgetKit |
| 진단 | FestiCoreLogger, Mixpanel·Sentry 설정 |
| 테스트 | Swift Testing, Tuist Test Insights |

지원 환경: iOS 18.0 이상, iPhone, Xcode 27.1. 화면 변경 시 iPhone Duo의 접힌 상태와 펼친 상태를 모두 확인합니다.

## 빌드 환경

| 구성 | 용도 | 스킴 |
| --- | --- | --- |
| Stage | 로컬 개발과 CI 테스트 | `FestiCore-Stage` |
| Prod | 배포 구성 | `FestiCore-Prod` |

환경별 값은 `Config/Stage.xcconfig`와 `Config/Prod.xcconfig`에서 관리합니다. 설치와 설정 방법은 [개발 환경](docs/development.md)에 있습니다.

## 빠른 시작

[빠른 시작 가이드](docs/quick-start.md)에서 도구 설치, 워크스페이스 생성, Xcode 실행 순서를 확인하세요.

~~~bash
git clone https://github.com/FESTICORE/FestiCore-iOS.git
cd FestiCore-iOS
cp /path/to/GoogleService-Info.plist Projects/App/Resources/GoogleService-Info.plist
./make setup --no-open
open FestiCore.xcworkspace
~~~

## 개발 명령어

~~~bash
./make generate                   # 준비된 의존성으로 워크스페이스 재생성
./make build                      # Stage 시뮬레이터 앱 빌드
./make test                       # Stage 테스트 플랜 전체 실행
./make cache                      # Tuist 외부 모듈 캐시 준비
./make module Feature NewFeature  # 새 Feature 모듈 생성 예시
~~~

Festival 모듈의 파일을 추가하거나 이동한 뒤에는 `./make generate`로 워크스페이스를 다시 생성합니다. `./make build`는 Stage 시뮬레이터 빌드, `./make test`는 Stage 테스트 플랜 전체 실행입니다. 전체 명령과 모듈 이름 규칙은 [개발 환경](docs/development.md)을 따릅니다.

## 테스트와 CI

`FestiCore-Stage` 테스트 플랜은 PR에서 테스트 샤드와 커버리지 결과를 수집합니다. develop은 분산 테스트를 실행합니다. 검사 단계와 결과 확인 방법은 [테스트와 CI](docs/testing-ci.md)에 정리했습니다.

## 개발 가이드

- [디자인 시스템](docs/design-system.md): 토큰 출처와 DesignKit 사용
- [Live Activity](docs/live-activity.md): 위젯 구성과 남은 화면·기기 검증
- [TCA 패턴](docs/agent/tca-patterns.md), [화면 전환](docs/agent/tcaflow-navigation.md)
- [SwiftUI 패턴](docs/agent/swiftui-patterns.md), [Swift 코딩 규칙](docs/agent/swift-coding-rules.md)
- [의존성 주입](docs/agent/dependency-injection.md), [개발 환경](docs/agent/development-environment.md)

프로젝트 운영 규칙과 AI 에이전트 지침은 [AGENTS.md](AGENTS.md)를 기준으로 합니다.

## 브랜치 전략

`feature/<작업명>` 브랜치에서 작업하고 `develop`으로 PR을 보냅니다. 검증된 PR은 스쿼시 머지합니다. 자세한 규칙은 [Git 워크플로](docs/agent/git-workflow.md)에 있습니다.

## 문의

- [GitHub Issues](https://github.com/FESTICORE/FestiCore-iOS/issues)
- [GitHub Pull Requests](https://github.com/FESTICORE/FestiCore-iOS/pulls)
