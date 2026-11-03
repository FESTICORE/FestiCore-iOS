# Domain 모듈

- 기능 단위로 Domain 모듈을 둔다(`AuthDomain`, `FestivalDomain`, `TimetableDomain`). 새 모듈은 `Projects/Domain/<이름>Domain/Project.swift`로 등록하고 `Plugins/DependencyPlugin`의 Domain 목록, 조립 모듈, `FestiCore.xctestplan` 테스트 타깃을 함께 갱신한다.
- 폴더 구성:
  - `Interface/Sources/Entity`: 공개 값·오류 타입
  - `Interface/Sources/<기능>`: `Sendable` Repository·UseCase `*Interface` 계약, `DependencyKey`, `DependencyValues` 접근자, 테스트 Mock
  - `Sources/<기능>`: `*Impl`
  - `Sources/Model`: DTO·Mapper
  - `Sources/<이름>LiveDependencies.swift`: live 등록
- Feature가 쓰는 공개 값 타입은 해당 Domain `Interface/Sources/Entity`에 둔다. Feature 모듈 `Model`에 공개 엔티티를 두지 않는다. 팩 문서처럼 디코딩하는 모델은 Domain `Sources/Model`의 DTO·Mapper로 둔다.
- UseCase는 화면이 하는 일 단위로 묶고, 구현은 Repository·Service·Store·Client를 `@Dependency`로 사용한다. Feature는 UseCase만 주입한다.
- 의도한 예외: `FestivalDomain`의 알림 설정 UseCase는 Repository 없이 `FestiCoreDeviceInterface`의 `DeviceNotificationSettingsService`를 직접 주입받는다(`.service(.device, .interface)` 의존). 기기 인증이 Device 서비스 안에 있기 때문이다. Device 요청 타입은 `DeviceRegistrationRequest`처럼 API·APIEndpoint가 아니라 `Service/FestiCoreDevice/Sources`에 둔다.
