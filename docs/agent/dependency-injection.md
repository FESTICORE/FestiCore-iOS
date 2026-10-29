# 의존성 주입

`AppCoordinator.State()`는 Splash에서 시작하며, 완료 액션을 받아 Home으로 전환한다. `FestiCoreApp`은 각 `WindowGroup` 장면에서 루트 Store를 생성한다. Feature는 Point-Free `Dependencies`의 `@Dependency`로 필요한 클라이언트를 사용한다.

Core 모듈의 Interface와 구현 타깃은 경계를 나눈다. `FestiCoreStorage`는 `SharedValueStorageDependency.liveValue`를 제공하고, `ServiceAssembly`는 `NetworkClientDependency`와 `AuthServiceDependency`의 `liveValue`를 제공한다. `NetworkContainer`는 인증 서비스와 네트워크 클라이언트를 같은 수명주기로 조립한다. `FeatureAssembly`는 Feature와 `ServiceAssembly`를 앱에 연결한다.

`StorageAssembly.register(into:)`와 `ServiceDependencyAssembly.register(into:)`는 명시적으로 `DependencyValues`를 구성할 때 사용한다. 앱 시작점에서는 전역 등록하지 않는다. `AppDelegate`가 쓰는 기기 등록 서비스도 해당 모듈의 `liveValue`에서 제공한다. 테스트는 `TestStore` 또는 `withDependencies`에서 실제 네트워크·키체인 대신 결정적인 대역을 주입한다. WeaveDI는 사용하지 않는다.

`AuthDomain`은 Network/Auth Interface와 `APIEndpoint`에 의존한다. Repository는 `@Dependency`로 공용 클라이언트와 인증 서비스를 사용하고, 도메인 모듈이 자신의 live use case를 등록한다. APIEndpoint는 Domain/Auth에 의존하지 않는다. 실제 네트워크·Keychain 세션은 계속 `ServiceAssembly`에서 조립한다.

AuthDomain의 공개 계약은 `Interface/Sources`에 두고 `AuthInterface`, `AuthUseCaseInterface`, `OAuthUseCaseInterface`처럼 역할을 이름에 표시한다. 각 계약 파일에 DI 키와 접근자를 함께 두며, 구현 타깃의 `AuthLiveDependencies.swift`에서 `*Impl`을 등록한다. 테스트·프리뷰 기본 Mock은 누락된 주입을 이슈로 기록하고 오류를 반환한다. 성공 경로 테스트는 필요한 대역을 명시적으로 주입한다.

앱 타깃을 테스트 호스트로 사용하는 동안 앱 시작 경로에서도 테스트 기본값이 호출된다. `FestivalCatalogService`의 캐시·새로고침은 빈 목록, `PackSyncService`의 캐시 목록은 빈 목록을 반환한다. `DeviceRegistrationService.register`는 외부 등록 없이 오류를 던진다. 이 네 메서드는 테스트 호스트가 다른 테스트의 미연결 이슈나 프로세스 종료를 만들지 않도록 이슈를 기록하지 않는다. 나머지 미구현 메서드와 AuthDomain의 누락 주입 정책은 유지하며, 개별 동작 테스트에서는 대역을 명시적으로 주입한다.

의도적으로 로그아웃하는 동안 다른 인증 요청의 refresh가 401을 받으면 `festiCoreAuthSessionDidExpire` 알림이 발생할 수 있다. 후속 로그인 UI의 알림 관찰자는 로그아웃 진행 중 이 알림을 무시하거나 억제해야 한다.

의존성 경계를 변경할 때는 현재 `Project.swift`의 타깃 의존성과 실제 생성 위치를 먼저 확인한다.
