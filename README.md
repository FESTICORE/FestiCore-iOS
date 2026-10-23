# FestiCore iOS

<div align="center">

<img width="150" alt="FestiCore Logo" src="https://avatars.githubusercontent.com/u/345318911?v=4">

**축제 탐색 앱 FestiCore의 iOS 프로젝트**

![Platform](https://img.shields.io/badge/Platform-iOS-orange.svg)
![Swift](https://img.shields.io/badge/Swift-6-FA7343.svg?logo=swift&logoColor=white)
![iOS](https://img.shields.io/badge/iOS-18.0+-34C759.svg)
![Architecture](https://img.shields.io/badge/Architecture-TCA-purple.svg)
![Tuist](https://img.shields.io/badge/Tuist-4.206.0-blue.svg)

[아키텍처](#아키텍처) · [빠른 시작](#빠른-시작) · [개발 명령어](#개발-명령어)

</div>

## 프로젝트

FestiCore는 축제 앱의 iOS 기반을 개발하고 있습니다. 현재 `develop`에는 앱 진입점과 Home 화면, 네트워크·인증·저장소·로깅, 공통 UI 모듈이 있습니다. 화면별 제품 기능은 이후 Feature 모듈에서 구현합니다.

대상은 iOS 18.0 이상 iPhone이며, 번들 ID는 `io.festiCore.co`, Apple Team ID는 `N94CS4N6VR`입니다.

현재 구성된 기능과 기반:

- Stage·Prod 앱과 Home 화면
- HTTP 요청, 자격 증명 저장과 토큰 갱신
- Keychain·공유 값 저장소와 공통 로깅
- DesignKit 색상·Pretendard 타이포그래피·공통 UI
- Swift Testing, Tuist 테스트·빌드·번들 분석

## 스크린샷

앱 화면 캡처는 첫 기능 화면이 완성된 뒤 추가합니다.

## 아키텍처

SwiftUI 기반 Tuist 멀티모듈 프로젝트입니다. The Composable Architecture는 의존성으로 등록돼 있습니다. `Workspace.swift`가 `Projects/**`를 모으고 Stage 전체 테스트 스킴을 정의합니다.

~~~text
Projects/
├── App/                         # 앱 진입점과 환경 설정
├── Feature/
│   └── Home/                    # 현재 Home 화면
├── Service/
│   ├── ServiceAssembly/         # 공통 의존성 조립
│   └── FestiCoreAuth/           # 자격 증명 저장과 토큰 갱신
├── Core/
│   ├── FestiCoreLogger/         # 로그
│   ├── FestiCoreNetwork/        # HTTP 요청과 인증 인터셉터
│   └── FestiCoreStorage/        # Keychain과 공유 값 저장소
└── UI/
    ├── FestiCoreDesignKit/      # 코드 기반 색상·타이포그래피·간격
    ├── FestiCoreLiveActivity/   # 축제 Live Activity 데이터와 Widget 확장
    ├── FestiCoreSharedUI/       # 공통 화면 컴포넌트
    └── FestiCoreAnimation/      # 애니메이션 표시 API
~~~

### 의존성 흐름

~~~mermaid
flowchart TD
    App --> Home[Feature/Home]
    App --> ServiceAssembly
    App --> LiveActivity[UI/FestiCoreLiveActivity]
    LiveActivityExtension[Widget 확장] --> LiveActivity
    ServiceAssembly --> Auth[Service/FestiCoreAuth]
    ServiceAssembly --> Network[Core/FestiCoreNetwork]
    ServiceAssembly --> Storage[Core/FestiCoreStorage]
    Auth --> Network
    Auth --> Storage
    Network --> Logger[Core/FestiCoreLogger]
    Auth --> Logger
~~~

설계 원칙:

- **App**은 Home, ServiceAssembly, DesignKit, LiveActivity에 직접 의존하며 앱 진입점과 환경 설정을 소유합니다.
- **FestiCoreLiveActivity**는 앱과 Widget 확장이 공유하는 축제 상태를 정의합니다. Widget 확장은 앱에 포함됩니다.
- **ServiceAssembly**는 인증 서비스, Network Interface, Storage 구현을 연결합니다.
- **FestiCoreNetwork**와 **FestiCoreStorage**는 Interface와 구현 타깃을 분리합니다.
- 리소스를 포함하는 **FestiCoreDesignKit**과 **FestiCoreAnimation**은 동적 프레임워크입니다.
- Domain/Data 모듈은 실제 기능의 모델과 저장소 계약이 생길 때 추가합니다.

### 의존성 주입

별도 런타임 DI 컨테이너 대신 Point-Free Dependencies를 사용합니다.

- **ServiceAssembly**: 인증, Network, Storage의 라이브 의존성 조립
- **FestiCoreNetwork**: `FestiCoreDataRequest` 요청 명세와 HTTP 클라이언트 제공
- **FestiCoreAuth**: 자격 증명 저장과 만료 토큰 갱신
- **App**: ServiceAssembly에서 조립한 의존성을 앱 시작 시 사용

일반 요청에는 `NetworkClientFactory.plain(baseURL:)`, 인증 요청에는 `NetworkClientFactory.unified(store:refresher:baseURL:)`를 사용합니다. 로그인·로그아웃 시에는 반환된 `credentials.update(_:)`로 자격 증명을 갱신합니다.

### 모듈 그래프

현재 `Projects/**/Project.swift`에 선언된 내부 타깃 의존성을 간추린 그래프입니다. 앱에 연결되지 않은 UI 모듈은 별도로 표시합니다.

<details>
<summary>FestiCore 전체 모듈</summary>

~~~mermaid
flowchart TD
    App --> Home
    App --> ServiceAssembly
    App --> FestiCoreDesignKit
    App --> FestiCoreLiveActivity
    App --> FestiCoreLiveActivityExtension
    FestiCoreLiveActivityExtension --> FestiCoreLiveActivity
    ServiceAssembly --> FestiCoreAuth
    ServiceAssembly --> FestiCoreNetworkInterface["FestiCoreNetwork / Interface"]
    ServiceAssembly --> FestiCoreStorage
    FestiCoreAuth --> FestiCoreNetwork
    FestiCoreAuth --> FestiCoreStorageImplementation["FestiCoreStorage / Implementation"]
    FestiCoreNetwork --> FestiCoreLogger
    FestiCoreSharedUI
    FestiCoreAnimation
~~~

</details>

<details>
<summary>인증·네트워크 경계</summary>

~~~mermaid
flowchart LR
    ServiceAssembly --> NetworkInterface["Network Interface"]
    ServiceAssembly --> FestiCoreAuth
    FestiCoreAuth --> NetworkImplementation["Network Implementation"]
    FestiCoreAuth --> StorageImplementation["Storage Implementation"]
    NetworkImplementation --> FestiCoreLogger
~~~

</details>

### Live Activity

`FestiCoreLiveActivity`의 `FestiCoreFestivalLiveActivity.start/update/end`로 축제 상태를 표시하고 종료할 수 있습니다. 앱은 Live Activity를 지원하며 `FestiCoreLiveActivityExtension`을 포함합니다. 현재 기능 화면에서 자동 시작하지 않고, 축제 상세 흐름이 생기면 사용자 동작에 연결합니다. 원격 갱신용 APNs 토큰 등록과 서버 연동은 아직 없습니다.

### 디자인 시스템

`FestiCoreDesignKit`은 [FestiCore-DesignSystem](https://github.com/FESTICORE/FestiCore-DesignSystem)의 토큰에서 생성한 Swift 색상·타이포그래피·간격을 제공합니다. 원본 JSON과 출처 SHA를 함께 보관하며, 토큰 동기화 워크플로가 변경 PR을 만듭니다. SwiftUI modifier를 이어서 사용합니다.

동기화 워크플로는 6시간마다 원본 `main`을 확인합니다. 생성물이나 원본 토큰이 바뀌면 검증 후 `develop` 대상 PR을 만들고, 현재 스냅샷과 같으면 새 PR을 만들지 않습니다. GitHub Actions에서 수동으로도 실행할 수 있습니다.

~~~swift
Text("Festival")
  .festiCoreTextStyle(FestiCoreTypography.baseBodyRegular)
  .foregroundStyle(Color.labelNormal)
  .padding(FestiCoreSpacing.marginM12)
~~~

## 기술 스택

| 영역 | 기술 |
|---|---|
| 언어 | Swift 6, Swift Concurrency |
| UI | SwiftUI |
| 상태 관리 | The Composable Architecture 패키지 설정 |
| 내비게이션 | TCAFlow 1.2.0 패키지 설정 |
| 프로젝트 | Tuist 4.206.0, Mise |
| 의존성 주입 | Point-Free Dependencies |
| 네트워크 | FestiCoreNetwork, Alamofire 5.12.0 |
| 인증 | FestiCoreAuth, GoogleSignIn 9.2.0·AppAuth 패키지 설정 |
| 저장소 | FestiCoreStorage, Keychain, SQLiteData |
| 이미지 | SDWebImageSwiftUI 3.1.4, Kingfisher 8.14.0 패키지 설정 |
| 모니터링 | Firebase Crashlytics 패키지 설정 |
| 테스트 | Swift Testing, Tuist Test Insights |

`Tuist/Package.swift`에는 GoogleSignIn, Firebase, AppAuth, TCAFlow도 등록돼 있습니다. 패키지 등록만으로 앱 기능이 완성된 것은 아니므로 실제 사용은 해당 모듈 소스를 기준으로 확인합니다.

### 로깅과 진단

- **FestiCoreLogger**: 공통 로그 API
- **Tuist Insights**: CI의 빌드·테스트·번들 결과 수집
- **Mixpanel·Sentry**: 도입 예정이며 현재 앱 코드에는 연결되지 않음

지원 환경:

- iOS 18.0 이상
- Swift 6
- Xcode 27.1
- iPhone

## 빌드 환경

| 구성 | 용도 | 스킴 |
| --- | --- | --- |
| Stage | 로컬 개발과 CI 테스트 | `FestiCore-Stage` |
| Prod | 배포 구성 | `FestiCore-Prod` |

프로젝트는 Dev 없이 두 구성만 사용합니다. 환경 값은 `Config/Stage.xcconfig`와 `Config/Prod.xcconfig`에서 관리합니다. Stage API 호스트는 `festicore-dev.up.railway.app`, Prod API 호스트는 `festicore.up.railway.app`입니다. 현재 프로젝트 버전 설정은 `1.0.0`입니다.

## 빠른 시작

### 요구사항

- Xcode 27.1
- Mise
- iOS 18.0 이상 iPhone 시뮬레이터

### 설치

~~~bash
git clone https://github.com/FESTICORE/FestiCore-iOS.git
cd FestiCore-iOS

# Mise 도구 설치 → Tuist 의존성 설치 → 캐시 준비 → 워크스페이스 생성
./make setup --no-open

open FestiCore.xcworkspace
~~~

Xcode에서 **FestiCore-Stage** 스킴과 사용할 iPhone 시뮬레이터를 선택해 실행합니다. 이미 도구와 의존성을 설치했다면 `./make generate`로 워크스페이스를 다시 생성할 수 있습니다.

## 개발 명령어

~~~bash
./make setup         # Mise 도구, 의존성, 로컬 캐시, 워크스페이스 준비
./make install       # 의존성 설치 후 워크스페이스 생성
./make generate      # 외부 바이너리 캐시를 사용해 프로젝트 재생성
./make build         # Stage 시뮬레이터 빌드
./make test          # Stage 플랜 전체 테스트
./make cache         # Tuist 외부 모듈 바이너리 캐시 준비
./make cache:setup   # Xcode Compilation Cache 준비
./make clean         # Tuist 생성물 정리
./make help          # 지원 명령 확인
~~~

새 모듈 생성:

~~~bash
./make module Feature Search
./make module Domain Festival
./make module Data Festival
./make module Core FestiCoreFoo
./make module UI FestiCoreFoo
./make module Service FestiCoreFoo
~~~

Core/UI/Service 모듈에는 `FestiCore` 접두어가 필요합니다. 생성 명령은 scaffold와 모듈 카탈로그를 갱신하며, 실제 의존성은 해당 `Project.swift`에서 명시합니다.

## 테스트와 CI

- `FestiCore-Stage` workspace 스킴의 `FestiCore` 테스트 플랜에 현재 테스트 타깃 9개가 등록되어 있습니다. 새 테스트 타깃을 추가하면 `Projects/App/Tests/FestiCore.xctestplan`에도 등록합니다.
- `./make test`는 `tuist test run FestiCore-Stage --test-plan FestiCore`를 사용하며 선택적 테스트와 격리된 테스트 생략을 비활성화해 전체 플랜을 실행합니다. `tuist test`만 실행하면 선택적 테스트가 기본 활성화됩니다.
- PR 워크플로는 self-hosted macOS 러너에서 Stage 테스트를 한 번 빌드하고 Tuist Test Sharding으로 두 shard에 나눠 실행합니다.
- 테스트는 `tuist test run`과 `--inspect-mode remote`로 실행하고 결과를 [Tuist 웹 프로젝트](https://tuist.dev/FestiCore/festicore)에 업로드합니다.
- Tuist Test Insights에서 테스트 케이스, 성공·실패와 실행 시간을 확인할 수 있습니다.
- 각 shard의 Swift Testing 결과와 커버리지를 모아 PR 리포트를 작성합니다.
- 앱 빌드가 성공하면 코드 서명 없이 Stage 디바이스 앱을 묶어 `FestiCore-Stage.ipa`를 만들고 Bundle Insights를 생성합니다.
- 번들 분석 결과는 PR 리포트에 반영하며 Tuist 서버에도 등록합니다. 테스트나 빌드가 실패한 경우에는 실패 결과를 리포트에 기록합니다.
- `develop` 워크플로도 Tuist Test Sharding으로 테스트를 분산하고 Stage 외부 모듈 캐시를 준비합니다.
- Xcode Compilation Cache와 Tuist 외부 패키지 바이너리 캐시는 사용할 수 있을 때 활성화합니다.

Tuist 웹 리포트:

- [Tests](https://tuist.dev/FestiCore/festicore/tests/test-runs): 테스트 실행과 테스트 케이스
- [Builds](https://tuist.dev/FestiCore/festicore/builds/build-runs): 빌드 성공 여부와 빌드 시간
- [Bundles](https://tuist.dev/FestiCore/festicore/bundles): 앱 번들 크기와 변경 추이

관련 워크플로:

- [.github/workflows/ios-pr.yml](.github/workflows/ios-pr.yml)
- [.github/workflows/ios-develop-sharded-tests.yml](.github/workflows/ios-develop-sharded-tests.yml)
- [.github/workflows/ios-cache-warm.yml](.github/workflows/ios-cache-warm.yml)
- [.github/workflows/ios-preview.yml](.github/workflows/ios-preview.yml)
- [.github/workflows/design-token-sync.yml](.github/workflows/design-token-sync.yml)

## 개발 가이드

- [TCA 패턴](docs/agent/tca-patterns.md)
- [SwiftUI 패턴](docs/agent/swiftui-patterns.md)
- [Swift 코딩 규칙](docs/agent/swift-coding-rules.md)
- [팝업과 모달](docs/agent/popup-modal-system.md)
- [TCAFlow 내비게이션](docs/agent/tcaflow-navigation.md)
- [개발 환경](docs/agent/development-environment.md)
- [Git 워크플로](docs/agent/git-workflow.md)
- [의존성 주입](docs/agent/dependency-injection.md)
- [테스트·PR 자동화](docs/agent/test-auto-pr-agent.md)

프로젝트 운영 규칙과 AI 에이전트 지침은 [AGENTS.md](AGENTS.md)를 기준으로 합니다. 설계 배경은 [초기 설정 설계](docs/initial-setup-design.md)와 [Core·UI 설계](docs/core-ui-modules-design.md)에 있습니다.

## 브랜치 전략

- **main**: 릴리스 기준. `fastlane/`의 테스트·빌드·QA·릴리스·심사 제출 lane으로 배포를 준비합니다.
- **develop**: 개발 통합. 푸시하면 shard 테스트와 Tuist Preview 워크플로가 실행됩니다.
- 기능·수정 브랜치 → develop Pull Request

배포 인증 값은 실행 환경에서 주입합니다. 실제 기기 서명과 App Store 배포는 아직 검증하지 않았습니다.

## 문의

- [GitHub Issues](https://github.com/FESTICORE/FestiCore-iOS/issues)
- [Pull Requests](https://github.com/FESTICORE/FestiCore-iOS/pulls)
- [FestiCore DesignSystem](https://github.com/FESTICORE/FestiCore-DesignSystem)

<div align="center">

Made with ❤️ by FestiCore

</div>
