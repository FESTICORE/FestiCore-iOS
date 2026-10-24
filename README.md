# FestiCore iOS

FestiCore 축제 앱의 iOS 프로젝트입니다. SwiftUI와 Tuist로 구성하며 iOS 18.0 이상 iPhone을 지원합니다.

현재 `develop`에는 앱 진입점과 Home 화면, 네트워크·인증·저장소·로깅, DesignKit과 공통 UI가 있습니다. 축제별 제품 화면은 아직 구현 중입니다. Live Activity용 앱 API와 Widget 확장은 있으나, 화면 흐름에서 활동을 시작하지 않으며 실제 기기 표시와 원격 갱신은 검증되지 않았습니다.

## 시작하기

도구 설치, 워크스페이스 생성, Xcode 실행 방법은 [빠른 시작](docs/quick-start.md)을 따릅니다.

| 명령 | 용도 |
| --- | --- |
| `./make build` | Stage 시뮬레이터 앱 빌드 |
| `./make test` | Stage 테스트 플랜 전체 실행 |
| `./make help` | 지원 명령 확인 |

## 구조

`Workspace.swift`가 `Projects/**`의 Tuist 프로젝트를 포함합니다. 앱은 SwiftUI를 사용하고 Home 상태는 TCA, 화면 연결은 TCAFlow가 맡습니다.

| 모듈 | 역할 |
| --- | --- |
| `App` | 앱 진입점, 화면 연결, Stage·Prod 설정 |
| `Feature` | 화면과 Reducer |
| `Service` | 인증, 기기 등록, 의존성 조립 |
| `Core` | 네트워크, 저장소, 로깅 |
| `UI` | DesignKit, 공통 UI, Live Activity 공유 상태 |
| `Widget` | 잠금 화면과 Dynamic Island의 Live Activity 확장 |

`FestiCoreApp.init()`에서 `ServiceDependencyAssembly`를 등록합니다. Service는 Core의 구현을 조립하고, 테스트는 Point-Free Dependencies의 의존성 값을 교체합니다. Widget 확장은 공유 ActivityAttributes만 참조하며 네트워크·인증 구현에는 의존하지 않습니다. 구체적인 기능 계약이 생기면 Domain/Data 모듈을 추가합니다.

## 문서

- [빠른 시작](docs/quick-start.md): 개발 도구, 워크스페이스, 첫 실행
- [개발 환경](docs/development.md): Stage·Prod, 명령어, 설정값
- [테스트와 CI](docs/testing-ci.md): 전체 테스트, PR 검사, Tuist 결과
- [디자인 시스템](docs/design-system.md): 토큰 출처, 동기화, DesignKit 사용
- [Live Activity](docs/live-activity.md): 구현 범위와 남은 연결·검증 작업
- [개발 규칙](AGENTS.md)과 [에이전트 가이드](docs/agent/): 코드·협업 규칙

문제 제안과 변경 사항은 [GitHub Issues](https://github.com/FESTICORE/FestiCore-iOS/issues) 및 [Pull Requests](https://github.com/FESTICORE/FestiCore-iOS/pulls)에서 관리합니다.
