# 의존성 주입

현재 앱의 `FestiCoreApp`은 `AppConfiguration`을 읽어 Home 화면에 전달한다. Core 모듈은 Point-Free `Dependencies`의 `DependencyValues`로 필요한 클라이언트를 주입한다.

Core 모듈의 Interface와 구현 타깃은 경계를 나누기 위한 구조다. 기능은 필요한 인터페이스를 의존한다. `FestiCoreStorage`가 저장소 의존성 등록을 소유하고, `CoreAssembly`의 `StorageAssembly`가 그 등록을 호출한다. `ServiceAssembly`는 `CoreAssembly`를 사용해 인증 서비스와 네트워크 클라이언트를 같은 수명주기로 조립하고 live `DependencyKey`를 제공한다. 앱은 `ServiceDependencyAssembly.register(into:)`를 호출한다. 테스트에는 실제 네트워크·키체인 대신 결정적인 대역을 주입한다.

의존성 경계를 변경할 때는 현재 `Project.swift`의 타깃 의존성과 실제 생성 위치를 먼저 확인한다.
