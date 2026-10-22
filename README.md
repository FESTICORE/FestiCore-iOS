# FestiCore iOS

<div align="center">

**축제 탐색 앱 FestiCore의 iOS 프로젝트**

![Platform](https://img.shields.io/badge/Platform-iOS-orange.svg)
![Swift](https://img.shields.io/badge/Swift-6-FA7343.svg?logo=swift&logoColor=white)
![iOS](https://img.shields.io/badge/iOS-18.0+-34C759.svg)
![Architecture](https://img.shields.io/badge/Architecture-TCA-purple.svg)
![Tuist](https://img.shields.io/badge/Tuist-4.206.0-blue.svg)

[아키텍처](#아키텍처) · [빠른 시작](#빠른-시작) · [개발 명령어](#개발-명령어) · [테스트와 CI](#테스트와-ci)

</div>

## 프로젝트

FestiCore는 축제 앱의 iOS 기반을 개발하고 있습니다. 현재 `develop`에는 앱 진입점과 Home 화면, 네트워크·인증·저장소·로깅, 공통 UI 모듈이 있습니다. 화면별 제품 기능은 이후 Feature 모듈에서 구현합니다.

대상은 iOS 18.0 이상 iPhone이며, 번들 ID는 `io.festiCore.co`, Apple Team ID는 `N94CS4N6VR`입니다.

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
    ├── FestiCoreDesignSystem/   # 코드 기반 색상·타이포그래피·간격
    ├── FestiCoreSharedUI/       # 공통 화면 컴포넌트
    └── FestiCoreAnimation/      # 애니메이션 표시 API
~~~

### 의존성 흐름

~~~mermaid
flowchart TD
    App --> Home[Feature/Home]
    App --> ServiceAssembly
    ServiceAssembly --> Auth[Service/FestiCoreAuth]
    ServiceAssembly --> Network[Core/FestiCoreNetwork]
    ServiceAssembly --> Storage[Core/FestiCoreStorage]
    Auth --> Network
    Auth --> Storage
    Network --> Logger[Core/FestiCoreLogger]
    Auth --> Logger
~~~

실제 타깃 의존성은 각 모듈의 `Project.swift`가 기준입니다. `FestiCoreNetwork`와 `FestiCoreStorage`는 `Interface`와 `Sources` 타깃을 분리합니다. `ProjectTemplatePlugin`은 모듈·스킴·설정을 만들고, `DependencyPlugin`과 `DependencyPackagePlugin`은 내부·외부 의존성을 정의합니다. Domain/Data는 아직 생성하지 않았으며 기능 구현에 맞춰 추가합니다.

### 의존성 주입과 네트워크

Point-Free Dependencies를 사용합니다. `ServiceAssembly`가 인증 서비스와 네트워크·저장소의 라이브 의존성을 조립합니다. 일반 요청은 `FestiCoreDataRequest`로 정의하고 `NetworkClientFactory.plain(baseURL:)`의 클라이언트로 보냅니다. 인증 요청은 `NetworkClientFactory.unified(store:refresher:baseURL:)`에 자격 증명 저장소와 갱신기를 주입합니다. 로그인·로그아웃 시 반환된 `credentials.update(_:)`로 자격 증명을 갱신합니다.

### 디자인 시스템

`FestiCoreDesignSystem`은 [FestiCore-DesignSystem](https://github.com/FESTICORE/FestiCore-DesignSystem)의 토큰을 참조한 Swift 색상·타이포그래피·간격을 제공합니다. 현재 값은 코드 스냅샷이며 원천 저장소에서 iOS로 자동 반영하는 작업은 별도로 진행 중입니다. SwiftUI modifier를 이어서 사용합니다.

~~~swift
Text("Festival")
  .festiCoreTextStyle(FestiCoreTypography.baseBodyRegular)
  .foregroundStyle(Color.festiCore(FestiCoreColor.labelNormal))
  .padding(FestiCoreSpacing.marginM12)
~~~

## 기술 스택

| 영역 | 기술 |
| --- | --- |
| 언어·UI | Swift 6, SwiftUI |
| 상태·의존성 | The Composable Architecture, Point-Free Dependencies |
| 프로젝트 | Tuist 4.206.0, Mise |
| 네트워크 | FestiCoreNetwork, Alamofire |
| 인증·저장소 | FestiCoreAuth, FestiCoreStorage, Keychain, SQLiteData |
| 이미지 | SDWebImageSwiftUI, Kingfisher 패키지 설정 |
| 테스트 | Swift Testing, Tuist Test Insights |

`Tuist/Package.swift`에는 GoogleSignIn, Firebase, AppAuth, TCAFlow도 등록돼 있습니다. 패키지 등록만으로 앱 기능이 완성된 것은 아니므로 실제 사용은 해당 모듈 소스를 기준으로 확인합니다.

## 빌드 환경

| 구성 | 용도 | 스킴 |
| --- | --- | --- |
| Stage | 로컬 개발과 CI 테스트 | `FestiCore-Stage` |
| Prod | 배포 구성 | `FestiCore-Prod` |

설정은 `Config/Stage.xcconfig`와 `Config/Prod.xcconfig`에서 관리합니다. 현재 API 호스트는 `stage.example.invalid`, `api.example.invalid` 예시 값입니다. 서버에 연결하려면 개발 `https://festicore-dev.up.railway.app`, 운영 `https://festicore.up.railway.app`에 맞게 환경 설정을 완료해야 합니다. 현재 프로젝트 버전 설정은 `0.1.0`입니다.

## 빠른 시작

### 요구사항

- Xcode 27.1
- Mise
- iOS 18.0 이상 iPhone 시뮬레이터

~~~bash
git clone https://github.com/FESTICORE/FestiCore-iOS.git
cd FestiCore-iOS
./make setup
./make generate
open FestiCore.xcworkspace
~~~

Xcode에서 `FestiCore-Stage` 스킴과 사용 가능한 iPhone 시뮬레이터를 선택합니다. `./make generate`는 기본적으로 workspace를 자동으로 열지 않습니다.

## 개발 명령어

~~~bash
./make setup                    # Mise 도구와 Tuist 의존성 설치
./make install                  # Tuist 의존성 설치
./make generate                 # FestiCore.xcworkspace 생성
./make build                    # Stage 시뮬레이터 빌드
./make test                     # Stage 시뮬레이터 테스트
./make clean                    # Tuist 생성물 정리
./make help                     # 지원 명령 확인
./make module Feature Search    # Feature 모듈 생성·카탈로그 등록
./make module Core FestiCoreFoo # Core 모듈 생성·카탈로그 등록
~~~

모듈 생성기는 `Feature`, `Domain`, `Data`, `Core`, `UI`를 지원합니다. Core/UI 이름에는 `FestiCore` 접두어가 필요합니다. 생성된 모듈의 실제 의존성은 해당 `Project.swift`에서 명시합니다.

## 테스트와 CI

- `FestiCore-Stage` workspace 스킴이 테스트 타깃을 수집하고 관련 타깃의 커버리지를 집계합니다.
- PR 워크플로는 self-hosted macOS 러너에서 `tuist test run`으로 테스트를 두 shard로 나누고, Swift Testing 결과·커버리지·앱 번들 크기를 PR 리포트에 기록합니다.
- 테스트와 빌드는 Tuist Test/Build Insights로 업로드합니다. 앱 번들 분석도 성공한 테스트 뒤 실행합니다.
- `develop` 워크플로는 전체 테스트를 shard로 실행하고 Stage 모듈 캐시를 준비합니다. Xcode Compilation Cache와 Tuist 캐시는 사용 가능한 경우 활성화합니다.
- Tuist 웹의 PR 앱 댓글과 `tuist/bundle-size` 체크는 GitHub 앱의 저장소 연결 및 번들 임계값 설정이 필요합니다. 현재 GitHub Actions PR 리포트와는 별개의 연동입니다.

Tuist 웹 프로젝트: [Tests](https://tuist.dev/suhwj81/festicore/tests/test-runs) · [Builds](https://tuist.dev/suhwj81/festicore/builds/build-runs) · [Bundles](https://tuist.dev/suhwj81/festicore/bundles)

관련 워크플로: [.github/workflows/ios-pr.yml](.github/workflows/ios-pr.yml), [.github/workflows/ios-develop-sharded-tests.yml](.github/workflows/ios-develop-sharded-tests.yml).

## 개발 가이드

- [개발 환경](docs/agent/development-environment.md)
- [Git·PR](docs/agent/git-workflow.md)
- [Swift 규칙](docs/agent/swift-coding-rules.md)
- [TCA 패턴](docs/agent/tca-patterns.md)
- [의존성 주입](docs/agent/dependency-injection.md)
- [SwiftUI 패턴](docs/agent/swiftui-patterns.md)
- [팝업과 모달](docs/agent/popup-modal-system.md)
- [테스트·PR 자동화](docs/agent/test-auto-pr-agent.md)

프로젝트 운영 규칙과 AI 에이전트 지침은 [AGENTS.md](AGENTS.md)를 기준으로 합니다. 설계 배경은 [초기 설정 설계](docs/initial-setup-design.md)와 [Core·UI 설계](docs/core-ui-modules-design.md)에 있습니다.

## 브랜치 전략

- `main`: 운영 배포 기준
- `develop`: 개발 통합과 shard 테스트
- 기능·수정 브랜치 → `develop` Pull Request

이번 초기 설정 이슈의 커밋 제목에는 `#3`을 붙입니다. 배포 인증 값과 개인 설정은 저장소에 넣지 않습니다.

## 문의

- [GitHub Issues](https://github.com/FESTICORE/FestiCore-iOS/issues)
- [Pull Requests](https://github.com/FESTICORE/FestiCore-iOS/pulls)
