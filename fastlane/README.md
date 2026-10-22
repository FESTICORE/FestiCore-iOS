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
