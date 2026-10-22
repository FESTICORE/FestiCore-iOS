# FestiCore iOS

축제 앱의 iOS 프로젝트입니다. iOS 18.0 이상 iPhone을 대상으로 하며, 앱 식별자는 `io.festiCore.co`, Apple Team ID는 `N94CS4N6VR`입니다.

## 시작

Xcode 27.1과 mise를 설치한 뒤 저장소 루트에서 실행합니다.

```sh
./make setup
./make generate
./make test
```

`./make help`에서 명령을 볼 수 있습니다. 생성된 `FestiCore.xcworkspace`의 `FestiCore-Stage` 스킴을 실행합니다. `FestiCore-Prod`는 배포 설정입니다. API 호스트는 `Config/Stage.xcconfig`의 개발 서버와 `Config/Prod.xcconfig`의 운영 서버로 나뉩니다.

`./make setup`은 의존성 설치, Xcode Compilation Cache 설정, 외부 모듈의 로컬 Tuist 바이너리 캐시 준비와 프로젝트 생성을 순서대로 실행합니다. `./make cache`로 외부 모듈 캐시를 따로 준비할 수 있습니다. `./make generate`와 PR CI는 `only-external` 캐시 프로필로 워크스페이스를 생성하며, `develop`에서는 캐시 warm 작업을 별도로 실행합니다.

## 모듈 구조

`Workspace.swift`가 `Projects/**`를 모으고, 세 플러그인이 프로젝트 템플릿·내부 의존성·외부 패키지 의존성을 분리합니다.

```text
Projects/App
  ├─ Sources/Application   # 앱 진입점·AppDelegate·환경 설정
  └─ Resources/Assets.xcassets
Projects/Feature/Home
Projects/Core/
  ├─ FestiCoreLogger
  ├─ FestiCoreNetwork       # Interface / Sources / Tests
  └─ FestiCoreStorage       # Interface / Sources / Tests
Projects/UI/
  ├─ FestiCoreAnimation
  ├─ FestiCoreDesignKit
  └─ FestiCoreSharedUI
Projects/Service/
  ├─ FestiCoreAuth
  └─ ServiceAssembly
```

`ProjectTemplatePlugin`은 Stage/Prod 설정과 모듈 타깃을 만들고, `DependencyPlugin`의 카탈로그가 `.feature(.home)`, `.core(.network)`, `.ui(.designSystem)` 같은 참조를 제공합니다. `DependencyPackagePlugin`은 외부 패키지 의존성 명명 공간을 제공합니다. Domain/Data는 기능별로 실체가 생길 때 추가합니다.

```sh
./make module Feature Search
```

이 명령은 `Projects/Feature/Search`의 매니페스트·소스·테스트 파일을 만들고 카탈로그에 등록한 뒤 워크스페이스를 생성합니다. 파일 헤더의 프로젝트·작성자 이름은 FestiCore입니다. 새 모듈의 실제 의존성은 생성된 `Project.swift`에서 명시합니다. 지원 레이어는 `Feature`, `Domain`, `Data`, `Core`, `UI`입니다. Core/UI 모듈 이름에는 `FestiCore` 접두어가 필요합니다.

## Core와 UI 사용 범위

Core에는 로깅, Alamofire 기반 네트워크 요청·인증 갱신, Keychain·공유 값 저장소가 있습니다. Network의 `Interface`에는 `FestiCoreDataRequest`, `FestiCoreNetworkClient`, `CredentialStore`, `TokenRefreshing` 공개 계약이 있고, `Sources`에는 요청 클라이언트와 `NetworkClientFactory`가 있습니다.

- 일반 요청: 요청 타입을 `FestiCoreDataRequest`로 정의하고 `NetworkClientFactory.plain(baseURL:)`로 만든 클라이언트에서 `send(_:)` 또는 `send(_:as:)`를 호출합니다.
- 인증 요청: `ServiceAssembly`가 Keychain 저장소, 토큰 갱신기와 `NetworkClientFactory.unified(store:refresher:baseURL:)`를 조립합니다. 로그인·로그아웃은 `AuthService`를 통해 저장소와 인증 클라이언트를 함께 갱신합니다.

실제 서버 엔드포인트가 확정되기 전까지 실행 가능한 API 호출 코드는 예제로 싣지 않습니다.

UI의 `FestiCoreDesignKit`에는 [FestiCore-DesignSystem](https://github.com/FESTICORE/FestiCore-DesignSystem) 토큰을 참조한 Swift 색상·레이아웃·타이포그래피 코드가 있습니다. SwiftUI에서는 modifier를 이어서 사용합니다.

생성된 색상 코드는 `Projects/UI/FestiCoreDesignKit/Sources/Token/Color/`의 `Color`, `UIColor`, `ShapeStyle` 확장에 둡니다. 레이아웃과 타이포그래피는 각각 `Sources/Token/Layout/`, `Sources/Token/Typography/`에 둡니다. 원본 JSON은 `Tests/Resources/Tokens/`에, 출처 커밋은 `TokenSnapshot/.source-sha`에 보관합니다. 이미지 리소스용 `Resources/ImageAssets.xcassets`는 현재 비어 있습니다. Pretendard Variable 글꼴과 라이선스는 `Resources/FontAsset/`에 있으며, 글꼴 등록과 SwiftUI 스타일은 `Sources/Token/Typography/`에서 처리합니다. 수작업 컴포넌트와 SwiftUI 확장은 `Sources/Component/` 및 `Sources/Token/`의 별도 파일로 관리합니다.

DesignSystem 저장소의 토큰 변경이 `main`에 머지되면 iOS의 `Sync design tokens` 워크플로가 매주 또는 수동 실행 시 원본 SHA를 고정해 가져옵니다. 원본 검사, DesignKit 및 Stage 테스트, 커버리지가 통과하면 `develop` 대상 `chore/design-tokens-sync` PR을 만들거나 갱신합니다. 같은 SHA면 PR을 만들지 않습니다. PR 작성 권한은 저장소 Actions 설정에서 허용되어야 합니다.

```swift
Text("Festival")
  .festiCoreTextStyle(FestiCoreTypography.baseBodyRegular)
  .foregroundStyle(Color.labelNormal)
  .padding(FestiCoreSpacing.marginM12)
```

`FestiCoreAnimation`은 호출자가 제공한 번들의 애니메이션을 표시하고, `FestiCoreSharedUI`는 공통 섹션 컴포넌트를 제공합니다.

## AI 작업 문서

[AGENTS.md](AGENTS.md)에 작업·커밋·검증 규칙과 주제별 문서 목록이 있습니다. [개발 환경](docs/agent/development-environment.md), [Git·PR](docs/agent/git-workflow.md), [테스트 자동화](docs/agent/test-auto-pr-agent.md) 가이드도 참고합니다. Claude Code의 공유 훅 설정은 `.claude/settings.json`에 있으며 개인 설정과 메모리는 추적하지 않습니다.

## 검증과 배포 설정

```sh
bash Scripts/check-tracked-secrets.sh
./make build
./make test
bundle install
bundle exec fastlane ios test
bundle exec fastlane ios build
```

Fastlane은 `Gemfile`과 `fastlane/`에 정의합니다. `ios QA`, `ios release`, `ios submit_for_review`, `ios tdd_ci` lane이 있습니다. 배포 lane에는 `MATCH_GIT_URL`, `MATCH_PASSWORD`, `APP_STORE_CONNECT_TEAM_ID`, `APP_STORE_CONNECT_API_KEY_ID`, `APP_STORE_CONNECT_ISSUER_ID`, `APP_STORE_CONNECT_API_KEY_CONTENT`(Base64 인코딩)가 필요합니다. 인증 값은 저장소에 넣지 않습니다. 실기기 서명과 배포는 아직 검증하지 않았습니다.

`develop` 대상 PR에서는 프로젝트 생성, 시뮬레이터 빌드·테스트와 추적 파일 검사를 실행합니다. 작업 커밋의 한국어 제목 끝에는 이슈 번호 `#3`을 붙이고 PR에는 작업 유형 라벨을 붙입니다. 자세한 결정은 [초기 설정 설계](docs/initial-setup-design.md)와 [Core·UI 설계](docs/core-ui-modules-design.md)에 있습니다.
