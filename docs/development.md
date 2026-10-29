# 개발 환경

## 구성

| 구성 | 스킴 | API 호스트 |
| --- | --- | --- |
| Stage | `FestiCore-Stage` | `festicore-dev.up.railway.app` |
| Prod | `FestiCore-Prod` | `festicore.up.railway.app` |

`Config/Stage.xcconfig`와 `Config/Prod.xcconfig`가 환경 값과 현재 앱 버전 `1.0.0`을 정의합니다. 번들 ID는 `io.festiCore.co`입니다. Mixpanel 토큰과 Sentry DSN은 저장소에서 비워 두며 각각 `FESTICORE_MIXPANEL_TOKEN`, `FESTICORE_SENTRY_DSN` 빌드 설정으로 주입합니다. 값이 없으면 해당 SDK 초기화는 건너뜁니다. 로컬 Xcode 빌드에서는 Git 제외 대상인 `Config/Stage.local.xcconfig` 또는 `Config/Prod.local.xcconfig`에 `FESTICORE_SENTRY_DSN = <환경별 DSN>`을 적으면 각 환경 설정이 이를 포함합니다. Sentry 조직은 `festicore`, iOS 프로젝트는 `festicore-ios`입니다. iOS Preview CI는 저장소 Secret `FESTICORE_SENTRY_DSN`을 Stage 빌드에 주입합니다. App Store 빌드도 같은 이름의 환경 변수를 Fastlane에 전달해야 실제 오류가 전송됩니다. DSN이나 Wizard가 만든 `Projects/App/.sentryclirc`는 커밋하지 않습니다.

Google 로그인용 공개 클라이언트 ID와 URL 스킴은 두 `xcconfig`의 `GOOGLE_CLIENT_ID`(서버), `GOOGLE_IOS_CLIENT_ID`(iOS), `REVERSED_CLIENT_ID`에서 관리합니다. 로컬 Firebase 초기화에는 발급받은 `GoogleService-Info.plist`를 `Projects/App/Resources/GoogleService-Info.plist`에 복사한 뒤 `./make generate --no-open`을 실행합니다. 이 plist는 Git에서 제외됩니다. CI에서는 저장소 Secret `GOOGLE_SERVICE_INFO_PLIST_BASE64`로 같은 경로에 복원하고 번들 ID를 확인합니다.

## 명령어

저장소 루트의 `make` 실행 파일이 `TuistTool.swift`를 호출합니다.

| 명령 | 동작 |
| --- | --- |
| `./make setup --no-open` | Mise, Tuist 의존성, 캐시, 워크스페이스 준비 |
| `./make install --no-open` | 의존성과 캐시를 준비한 뒤 워크스페이스 생성 |
| `./make generate --no-open` | 현재 의존성으로 워크스페이스 재생성 |
| `./make build` | 서명 없는 Stage 시뮬레이터 빌드 |
| `./make test` | 최신 사용 가능 iOS 런타임의 iPhone Duo에서 Stage 테스트 플랜 전체 실행 ([대상 선택](testing-ci.md)) |
| `./make cache` | 외부 모듈 바이너리 캐시 준비 |
| `./make cache:setup` | Xcode Compilation Cache 설정 |
| `./make help` | 지원 명령 표시 |

`./make module <Layer> <Name>`은 `Feature`, `Domain`, `Data`, `Core`, `UI`, `Service` 레이어를 지원합니다. Core·UI·Service 이름은 `FestiCore` 접두어를 사용합니다. 생성 뒤 의존성은 해당 `Project.swift`에 명시합니다.

배포용 Fastlane lane과 서명 설정은 `fastlane/Fastfile`을 기준으로 확인합니다.
