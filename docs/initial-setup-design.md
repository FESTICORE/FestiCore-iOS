# FestiCore iOS 초기 설정 설계

## 목적

Attendance_iOS의 Tuist 플러그인 분리, 모듈 카탈로그, `make → TuistTool.swift` 개발 명령, Fastlane 구성, 이슈 기반 브랜치와 PR 흐름을 FestiCore에 적용한다. 앱 식별자는 `io.festiCore.co`, 개발팀은 `N94CS4N6VR`, 최소 배포 버전은 iOS 18.0이다. 첫 PR은 `develop`에 제출한다.

## 프로젝트와 의존성

- `Workspace.swift`는 `Projects/**`를 포함하고 Stage 스킴에 앱 테스트와 `Project.swift`/`Tests`가 있는 모든 모듈 테스트를 등록한다.
- `Tuist.swift`는 Tuist 웹 프로젝트 `suhwj81/festicore`를 참조한다. CI에 `TUIST_TOKEN`이 있으면 `tuist setup cache`와 Xcode 캐시 업로드를 활성화한다. 토큰으로 `tuist project show suhwj81/festicore --no-web` 조회를 확인했다. 실제 캐시 업로드는 토큰 설정 후 CI 실행에서 확인한다.
- `Plugins/ProjectTemplatePlugin`: Attendance처럼 `Configruation`, `Project+Templete`, `Scheme`, `Setting`, `infoPlist` helper 디렉터리에 앱 환경, Stage/Prod 빌드 설정, 모듈 타깃 및 Info.plist 템플릿을 분리한다. 앱 매니페스트는 `.appInfoPlist`, 모듈 타깃은 `.moduleInfoPlist`를 사용한다.
- `Plugins/DependencyPlugin`: `TargetDependency+Module`에 레이어 경로, 모듈 카탈로그, 내부 의존성 DSL을 둔다.
- `Plugins/DependencyPackagePlugin`: `DependencyPackage`에 외부 SPM 의존성 명명 공간을 둔다. Attendance의 패키지 버전을 유지하고 Kingfisher 8.14.0을 추가한다. 아직 앱 타깃에서 직접 사용하는 외부 패키지는 없다.
- `App`은 조립 지점이며 현재 화면 모듈은 Attendance와 같은 `Projects/Feature/Home` 경로와 `Home` 타깃을 사용한다. Domain/Data는 기능별 계약과 구현이 생길 때 모듈로 만든다. 의미 없는 공통 Domain/Data 타깃은 두지 않는다.
- `./make module <Feature|Domain|Data> <Name>`은 `Projects/<Layer>/<Name>`에 이름 그대로 프로젝트·소스·테스트를 생성하고 카탈로그에 등록한다. 파일 헤더의 프로젝트·작성자 이름은 FestiCore다. 앱이나 다른 모듈과의 의존성은 매니페스트에서 명시한다. 기존 경로, 중복 이름, Swift 예약어를 거부하고 생성에 실패하면 추가한 파일과 카탈로그를 원복한다.

## 환경과 배포

Stage와 Prod는 `Config/*.xcconfig`로 분리하고 앱 스킴은 `FestiCore-Stage`, `FestiCore-Prod`다. 초기 API 호스트는 `example.invalid`이며 실제 서버 계약을 구현한 값이 아니다. 로컬·CI 시뮬레이터 검증에서는 서명 없이 빌드한다.

Fastlane의 `test`와 `build`는 로컬 검증용이다. Attendance의 `QA`, `release`, `submit_for_review`, `tdd_ci` lane을 FestiCore 스킴과 앱 ID로 옮긴다. QA는 Stage의 Debug 구성으로 아카이브하며, Prod 스킴에는 Release 구성 테스트 액션을 두지 않는다. `release`는 Prod 빌드를 TestFlight에 업로드하고 App Store 버전을 준비한다. `submit_for_review`에는 검토할 `version`과 `build_number`를 명시한다. 배포 lane은 Match 저장소, 비밀번호, App Store Connect 팀과 API 키를 환경 변수로 받아 서명·아카이브·업로드한다. Attendance의 개인 Match 저장소, Slack 알림, 기존 앱 메타데이터와 인증 자료는 복사하지 않는다. TestFlight 업로드와 App Store 심사 제출은 이번 PR에서 실행하지 않는다.

## PR과 완료 기준

- GitHub 이슈 #1에서 `feature/1` 브랜치를 만들고 `develop`으로 PR을 연다.
- PR에 `⚙️ 환경설정` 라벨을 붙인다. Attendance 유형 라벨 9개를 저장소에 등록한다.
- 로컬에서 Tuist 생성, 시뮬레이터 빌드·테스트, Swift/Ruby 구문, 추적 비밀 파일 검사, `git diff --check`를 확인한다. 원격 CI 상태는 별도로 기록한다.
- PR에는 What/Why/How/Test와 검증하지 못한 항목을 적는다. 병합과 배포는 이 변경의 완료 기준이 아니다.
- Attendance와 같이 GitHub의 Codex 리뷰 앱을 사용한다. PR을 리뷰 가능한 상태로 열고 봇 리뷰를 확인한다. 자동 리뷰가 나타나지 않으면 `@codex review`를 요청하고, 설치 또는 권한으로 리뷰가 불가능하면 PR에 그 상태를 명시한다.
