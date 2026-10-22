# 개발 환경

## 현재 설정

- `Tuist.swift`는 Xcode 호환 버전, Swift 6.4와 플러그인을 설정한다.
- `Workspace.swift`는 `Projects/**`의 프로젝트를 모은다.
- `Config/Stage.xcconfig`와 `Config/Prod.xcconfig`는 환경별 빌드 값을 제공한다. API 호스트는 예시 값이므로 서버 연동 전에 실제 값을 확인한다.
- 앱 배포 대상은 iOS 18.0 이상 iPhone이다.

## 명령

저장소 루트의 `./make help`로 지원 명령과 인자를 확인한다. 처음 설정할 때 `./make setup`, 프로젝트 변경 뒤 `./make generate`, 검증 시 `./make build`와 `./make test`를 사용한다. 특정 시뮬레이터, 서명 및 원격 CI 결과는 각 실행 결과로 확인한다.

새 파일을 생성한 후에는 Tuist 프로젝트를 다시 생성해 Xcode에 반영한다. `.xcodeproj`와 `.xcworkspace`는 생성 산출물이다.
