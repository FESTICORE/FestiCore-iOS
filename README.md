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

`Projects/App`이 앱 진입점과 의존성을 조립합니다. `Feature`는 화면과 TCA 상태를, `Service`는 인증과 기기 등록을, `Core`는 네트워크·저장소·로깅을, `UI`는 디자인 요소와 Live Activity를 담당합니다. 모듈 경계와 의존성 흐름은 [아키텍처](docs/architecture.md)에 정리했습니다.

## 문서

- [빠른 시작](docs/quick-start.md): 개발 도구, 워크스페이스, 첫 실행
- [아키텍처](docs/architecture.md): 모듈, 의존성 주입, 네트워크 경계
- [개발 환경](docs/development.md): Stage·Prod, 명령어, 설정값
- [테스트와 CI](docs/testing-ci.md): 전체 테스트, PR 검사, Tuist 결과
- [디자인 시스템](docs/design-system.md): 토큰 출처, 동기화, DesignKit 사용
- [Live Activity](docs/live-activity.md): 구현 범위와 남은 연결·검증 작업
- [개발 규칙](AGENTS.md)과 [에이전트 가이드](docs/agent/): 코드·협업 규칙

문제 제안과 변경 사항은 [GitHub Issues](https://github.com/FESTICORE/FestiCore-iOS/issues) 및 [Pull Requests](https://github.com/FESTICORE/FestiCore-iOS/pulls)에서 관리합니다.
