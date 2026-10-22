# 의존성 주입

현재 앱의 `FestiCoreApp`은 `AppConfiguration`을 읽어 Home 화면에 전달한다. `Tuist/Package.swift`에는 Point-Free Dependencies가 TCA 의존성으로 포함되지만, WeaveDI와 앱 전역 DI 컨테이너는 없다.

Core 모듈의 Interface와 구현 타깃은 경계를 나누기 위한 구조다. 기능은 필요한 인터페이스를 의존하고, 구체 구현과 인증·저장소의 수명 관리는 앱 조립 지점에서 연결한다. 테스트에는 실제 네트워크·키체인 대신 결정적인 대역을 주입한다.

새 DI 패턴을 추가할 때는 현재 `Project.swift`의 타깃 의존성과 실제 생성 위치를 먼저 확인한다.
