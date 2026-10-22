# FestiCore iOS

축제 앱의 iOS 프로젝트입니다. iOS 18.0 이상 iPhone을 대상으로 하며, 앱 식별자는 `io.festiCore.co`, Apple Development Team ID는 `N94CS4N6VR`입니다.

## 시작

Xcode 27.1과 mise를 설치한 뒤 저장소 루트에서 실행합니다.

```sh
./make setup
./make generate
./make test
```

`./make help`에서 명령을 볼 수 있습니다. 생성된 `FestiCore.xcworkspace`의 `FestiCore-Stage` 스킴을 실행합니다. `FestiCore-Prod`는 배포 설정입니다. 두 API 호스트는 `Config/Stage.xcconfig`, `Config/Prod.xcconfig`의 예시 값이므로 서버 연결 전에 교체해야 합니다.

## 모듈 구조

Attendance_iOS처럼 `Workspace.swift`가 `Projects/**`를 모으고, 세 플러그인이 프로젝트 템플릿·내부 의존성·외부 패키지 의존성을 분리합니다.

```text
Projects/App
  └─ Feature/Home
```

`ProjectTemplatePlugin`은 Stage/Prod 설정과 모듈 타깃을 만들고, `DependencyPlugin`의 카탈로그가 `.feature(.home)` 같은 참조를 제공합니다. `DependencyPackagePlugin`은 Attendance와 같은 패키지 의존성 명명 공간을 제공합니다. Domain/Data는 기능별로 실체가 생길 때 추가합니다.

```sh
./make module Feature Search
```

이 명령은 `Projects/Feature/Search`의 매니페스트·소스·테스트 파일을 만들고 카탈로그에 등록한 뒤 워크스페이스를 생성합니다. 파일 헤더의 프로젝트·작성자 이름은 FestiCore입니다. 새 모듈의 실제 의존성은 생성된 `Project.swift`에서 명시합니다. 지원 레이어는 `Feature`, `Domain`, `Data`입니다.

## 검증과 배포 설정

```sh
bash Scripts/check-tracked-secrets.sh
./make build
./make test
bundle install
bundle exec fastlane ios test
bundle exec fastlane ios build
```

Fastlane은 `Gemfile`과 `fastlane/`에 정의합니다. Attendance에 대응하는 `ios QA`, `ios release`, `ios submit_for_review`, `ios tdd_ci` lane이 있습니다. 배포 lane에는 `MATCH_GIT_URL`, `MATCH_PASSWORD`, `APP_STORE_CONNECT_TEAM_ID`, `APP_STORE_CONNECT_API_KEY_ID`, `APP_STORE_CONNECT_ISSUER_ID`, `APP_STORE_CONNECT_API_KEY_CONTENT`(Base64 인코딩)가 필요합니다. 인증 값은 저장소에 넣지 않습니다. 실기기 서명과 배포는 아직 검증하지 않았습니다.

`develop` 대상 PR에서는 프로젝트 생성, 시뮬레이터 빌드·테스트와 추적 파일 검사를 실행합니다. 작업은 이슈 번호를 딴 `feature/<번호>` 브랜치에서 진행하고 PR에 작업 유형 라벨을 붙입니다. 자세한 결정은 [초기 설정 설계](docs/initial-setup-design.md)에 있습니다.
