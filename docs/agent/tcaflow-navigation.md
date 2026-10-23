# TCAFlow 네비게이션

`Tuist/Package.swift`에 TCAFlow 1.2.0이 선언되어 있다. `Projects/App/Sources/Navigation/AppCoordinator.swift`가 Home 루트 Route를 소유하고, `AppCoordinatorView`가 `TCAFlowRouter`로 화면을 렌더링한다. `FestiCoreApp`은 Coordinator Store를 생성한다.

여러 화면의 이동이 생기면 화면 소유 기능의 Route를 정의하고, push·present·dismiss와 상위 화면으로의 결과 전달을 테스트한다. URL 및 알림을 통한 진입은 앱의 실제 라우트가 생겼을 때 추가한다. 새 화면 이동을 위해 패키지 API를 사용하기 전에는 설치 버전과 실제 Feature 구조를 확인한다.

현재는 Home만 등록되어 있다. 실제 화면이 생길 때 `AppScreen`에 Route를 추가하고 이동·복귀 동작을 테스트한다.
