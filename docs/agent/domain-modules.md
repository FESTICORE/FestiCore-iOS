# Domain 모듈

- 기능 단위로 Domain 모듈을 둔다(`AuthDomain`, `FestivalDomain`, `TimetableDomain`). 새 모듈은 `Projects/Domain/<이름>Domain/Project.swift`로 등록하고 `Plugins/DependencyPlugin`의 Domain 목록, 조립 모듈, `FestiCore.xctestplan` 테스트 타깃을 함께 갱신한다.
- 파일을 만들기 전에 Attendance_iOS `Projects/Domain/AttendanceDomain`과 `Projects/Service/{API,APIEndpoint}`에서 같은 역할의 파일을 열어 배치와 주입 방식을 대조한다.
- 폴더 구성(Attendance `AttendanceDomain`과 같다):
  - `Interface/Sources/Entity`: 공개 값·오류 타입
  - `Interface/Sources/<기능>`: `Sendable` Repository·UseCase `*Interface` 계약, 테스트 Mock, `TestDependencyKey`(`testValue`·`previewValue`)와 `DependencyValues` 접근자
  - `Interface/Sources/Exported`: Interface 모듈의 `@_exported import`
  - `Sources/<기능>/<X>UseCaseImpl.swift`
  - `Sources/Repository/<X>RepositoryImpl.swift`, 로컬 저장은 `Sources/Repository/Local/<X>LocalDataSource.swift`
  - `Sources/Model/DTO`·`Sources/Model/Mapper`: DTO·Mapper
  - `Sources/<X>LiveDependencies.swift`: 모듈의 `extension <X>Dependency: DependencyKey` `liveValue` 등록을 한 파일에 모은다(Attendance `AttendanceLiveDependencies.swift`)
  - `Sources/Exported`: 구현 모듈의 `@_exported import`
- `FestivalDomain`의 계약별 `<계약 이름>+Live.swift`는 이전 배치다. 새 등록은 `<X>LiveDependencies.swift`에 둔다.
- Feature가 쓰는 공개 값 타입은 해당 Domain `Interface/Sources/Entity`에 둔다. Feature 모듈 `Model`에 공개 엔티티를 두지 않는다. 팩 문서처럼 디코딩하는 모델은 Domain `Sources/Model`의 DTO·Mapper로 둔다.
- UseCase는 화면이 하는 일 단위로 묶고, 구현은 Repository·Service·Store·Client를 `@Dependency`로 사용한다. Feature는 UseCase만 주입한다.
- 의도한 예외: `FestivalDomain`의 알림 설정 UseCase는 Repository 없이 `FestiCoreDeviceInterface`의 `DeviceNotificationSettingsService`를 직접 주입받는다(`.service(.device, .interface)` 의존). 기기 인증이 Device 서비스 안에 있기 때문이다. Device 요청 타입은 `DeviceRegistrationRequest`처럼 API·APIEndpoint가 아니라 `Service/FestiCoreDevice/Sources`에 둔다.
