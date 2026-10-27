# FestiCore iOS

<div align="center">

<img width="150" alt="FestiCore Logo" src="https://avatars.githubusercontent.com/u/345318911?v=4">

**축제를 위한 FestiCore iOS 앱**

![Platform](https://img.shields.io/badge/Platform-iOS-orange.svg)
![Swift](https://img.shields.io/badge/Swift-6-FA7343.svg?logo=swift&logoColor=white)
![iOS](https://img.shields.io/badge/iOS-18.0+-34C759.svg)
![Architecture](https://img.shields.io/badge/Architecture-TCA-purple.svg)
![Tuist](https://img.shields.io/badge/Tuist-4.206.0-blue.svg)

[아키텍처](#아키텍처) · [빠른 시작](#빠른-시작) · [개발 명령어](#개발-명령어) · [개발 가이드](#개발-가이드)

</div>

## 프로젝트

FestiCore는 축제를 위한 iOS 앱입니다. 현재 저장소에는 앱 진입점과 Home 화면, 공통 모듈, Live Activity 위젯의 기반이 있습니다. 축제 데이터 API를 사용하는 화면 흐름과 Live Activity의 화면상 시작 동작은 아직 구현되지 않았습니다.

현재 구성:

- Stage·Prod 앱과 TCA 기반 Home 화면
- 네트워크·인증·저장소·로깅의 모듈 경계와 의존성 조립
- 코드 기반 색상, base·point Pretendard 타이포그래피, 공통 UI
- ActivityKit 공유 모델과 독립 WidgetKit 확장
- Swift Testing, Tuist 프로젝트 생성 및 PR CI

## 스크린샷

제품 화면 캡처는 화면이 완성되고 실제 기기에서 확인한 뒤 추가합니다.

## 아키텍처

SwiftUI와 The Composable Architecture를 사용하는 Tuist 멀티모듈 프로젝트입니다. `Workspace.swift`가 `Projects/**`를 모으고, AppCoordinator는 TCAFlow로 화면을 연결합니다.

~~~text
Projects/
├── App/                         # 앱 진입점, 설정, 테스트 플랜
├── Feature/
│   ├── FeatureAssembly/         # 화면 모듈 조립
│   └── Home/                    # Home 화면과 Reducer
├── Service/
│   ├── ServiceAssembly/         # 서비스 의존성 조립
│   ├── FestiCoreAuth/           # 인증 세션과 토큰 갱신
│   └── FestiCoreDevice/         # 기기 등록 계약
├── Core/
│   ├── CoreAssembly/            # Core 구현 조립
│   ├── FestiCoreNetwork/        # HTTP 클라이언트
│   ├── FestiCoreStorage/        # Keychain과 저장소
│   └── FestiCoreLogger/         # 공통 로깅
├── UI/
│   ├── FestiCoreDesignKit/      # 디자인 토큰과 리소스
│   ├── FestiCoreSharedUI/       # 공통 UI
│   ├── FestiCoreAnimation/      # 애니메이션 표시 API
│   └── FestiCoreLiveActivity/   # 앱·위젯 공유 ActivityKit 타입
└── Widget/
    └── FestiCoreLiveActivityWidget/ # 잠금 화면·Dynamic Island 확장
~~~

### 의존성 흐름

~~~mermaid
flowchart TD
    App --> FeatureAssembly
    FeatureAssembly --> Home
    App --> ServiceAssembly
    ServiceAssembly --> FestiCoreAuth
    ServiceAssembly --> CoreAssembly
    CoreAssembly --> FestiCoreNetwork
    CoreAssembly --> FestiCoreStorage
    FestiCoreAuth --> FestiCoreNetwork
    FestiCoreAuth --> FestiCoreStorage
    App --> FestiCoreLiveActivity
    Widget --> FestiCoreLiveActivity
~~~

설계 원칙:

- App은 화면과 공통 서비스의 조립 결과를 사용합니다.
- ServiceAssembly는 인증과 Core 구현을 연결하고, CoreAssembly는 Network·Storage 구현을 등록합니다.
- Network·Storage는 Interface와 구현 타깃을 분리합니다.
- 위젯은 공유 ActivityKit 타입을 사용하며 앱의 네트워크·인증 구현에 의존하지 않습니다.
- Domain·Data 모듈은 실제 기능 계약이 생길 때 추가합니다.

### 의존성 주입

Point-Free Dependencies를 사용합니다. 앱 시작 시 `ServiceDependencyAssembly`를 등록하고, 각 모듈은 자신의 `DependencyKey`와 라이브 구현을 제공합니다. 테스트에서는 의존성 값을 교체합니다. 런타임 DI 컨테이너는 사용하지 않습니다.

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

지원 환경: iOS 18.0 이상, iPhone, Xcode 27.1.

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

전체 명령과 모듈 이름 규칙은 [개발 환경](docs/development.md)을 따릅니다.

## 테스트와 CI

`FestiCore-Stage` 테스트 플랜은 PR에서 테스트 샤드와 커버리지 결과를 수집합니다. develop은 분산 테스트를 실행합니다. 검사 단계와 결과 확인 방법은 [테스트와 CI](docs/testing-ci.md)에 정리했습니다.

## 개발 가이드

- [디자인 시스템](docs/design-system.md): 토큰 출처와 DesignKit 사용
- [Live Activity](docs/live-activity.md): 위젯 구성과 남은 화면·기기 검증
- [TCA 패턴](docs/agent/tca-patterns.md), [TCAFlow 내비게이션](docs/agent/tcaflow-navigation.md)
- [SwiftUI 패턴](docs/agent/swiftui-patterns.md), [Swift 코딩 규칙](docs/agent/swift-coding-rules.md)
- [의존성 주입](docs/agent/dependency-injection.md), [개발 환경](docs/agent/development-environment.md)

프로젝트 운영 규칙과 AI 에이전트 지침은 [AGENTS.md](AGENTS.md)를 기준으로 합니다.

## 브랜치 전략

`feature/<작업명>` 브랜치에서 작업하고 `develop`으로 PR을 보냅니다. 검증된 PR은 스쿼시 머지합니다. 자세한 규칙은 [Git 워크플로](docs/agent/git-workflow.md)에 있습니다.

## 문의

- [GitHub Issues](https://github.com/FESTICORE/FestiCore-iOS/issues)
- [GitHub Pull Requests](https://github.com/FESTICORE/FestiCore-iOS/pulls)
