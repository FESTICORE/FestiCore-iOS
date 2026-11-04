fastlane documentation
----

# Installation

Make sure you have the latest version of the Xcode command line tools installed:

```sh
xcode-select --install
```

For _fastlane_ installation instructions, see [Installing _fastlane_](https://docs.fastlane.tools/#installing-fastlane)

# Available Actions

## iOS

### ios provision_live_activity_signing

```sh
[bundle exec] fastlane ios provision_live_activity_signing
```

Live Activity 및 알림 확장의 Development 및 AppStore 프로파일 발급

### ios register_widget_app_group

```sh
[bundle exec] fastlane ios register_widget_app_group
```

기존 Apple ID 세션으로 앱·위젯 App Group만 연결 (프로파일 발급·빌드 없음)

### ios provision_widget_app_group

```sh
[bundle exec] fastlane ios provision_widget_app_group
```

앱·위젯 App Group 연결 및 Development·AppStore 프로파일 재발급 (빌드·배포 없음)

### ios test

```sh
[bundle exec] fastlane ios test
```

Stage 시뮬레이터 테스트

### ios build

```sh
[bundle exec] fastlane ios build
```

Stage 시뮬레이터 빌드

### ios QA

```sh
[bundle exec] fastlane ios QA
```

Attendance QA와 같은 Stage TestFlight 업로드

### ios distribute_internal

```sh
[bundle exec] fastlane ios distribute_internal
```

업로드한 빌드의 처리 완료를 기다린 뒤 FestiCore 내부 테스트 그룹에 배포

### ios distribute_external

```sh
[bundle exec] fastlane ios distribute_external
```

내부 배포가 끝난 빌드를 festiCore 외부 테스트 그룹에 넣고 베타 심사에 제출

### ios release

```sh
[bundle exec] fastlane ios release
```

Prod 빌드를 TestFlight에 업로드하고 App Store 버전을 준비

### ios submit_for_review

```sh
[bundle exec] fastlane ios submit_for_review
```

지정한 App Store 버전과 빌드를 심사 제출

### ios tdd_ci

```sh
[bundle exec] fastlane ios tdd_ci
```

Attendance tdd_ci에 대응하는 PR 시뮬레이터 검증

----

This README.md is auto-generated and will be re-generated every time [_fastlane_](https://fastlane.tools) is run.

More information about _fastlane_ can be found on [fastlane.tools](https://fastlane.tools).

The documentation of _fastlane_ can be found on [docs.fastlane.tools](https://docs.fastlane.tools).
