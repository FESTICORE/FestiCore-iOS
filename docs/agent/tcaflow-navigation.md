# 화면 전환

현재 `Projects/App/Sources/Navigation/Main/AppCoordinator.swift`는 Splash와 Home을 enum 상태로 관리한다. `AppCoordinatorView`는 상태에 맞는 화면을 표시한다. Splash 완료 액션은 Coordinator에서 Home 전환으로 연결한다.

TCAFlow 패키지는 프로젝트에 준비되어 있으나 현재 화면 전환에는 사용하지 않는다. 여러 화면의 push·present·dismiss가 필요해지면 실제 화면 구조에 맞춰 Route와 전환 테스트를 추가한다. URL과 알림 진입도 연결할 화면이 생길 때 정의한다.
