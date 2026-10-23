# 의존성 주입

`FestiCoreApp`은 `AppCoordinator` Store를 생성한다. `AppCoordinator.State`가 `AppConfiguration`을 읽어 초기 Home 상태를 만들며, 앱 진입점은 의존성 컨테이너를 부트스트랩하지 않는다. Feature는 Point-Free `Dependencies`의 `@Dependency`로 필요한 클라이언트를 사용한다.

Core 모듈의 Interface와 구현 타깃은 경계를 나눈다. `FestiCoreStorage`는 `SharedValueStorageDependency.liveValue`를 제공하고, `ServiceAssembly`는 `NetworkClientDependency`와 `AuthServiceDependency`의 `liveValue`를 제공한다. `NetworkContainer`는 인증 서비스와 네트워크 클라이언트를 같은 수명주기로 조립한다. `FeatureAssembly`는 Feature와 `ServiceAssembly`를 앱에 연결한다.

`StorageAssembly.register(into:)`와 `ServiceDependencyAssembly.register(into:)`는 명시적으로 `DependencyValues`를 구성할 때 사용한다. 앱 시작 시 이를 전역 등록하지 않는다. 테스트는 `TestStore` 또는 `withDependencies`에서 실제 네트워크·키체인 대신 결정적인 대역을 주입한다. WeaveDI는 사용하지 않는다.

의존성 경계를 변경할 때는 현재 `Project.swift`의 타깃 의존성과 실제 생성 위치를 먼저 확인한다.
