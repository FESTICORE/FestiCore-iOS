# 로컬 저장소

## 앱 내부 DB

앱 내부 DB(로컬 캐시·저장)는 SQLiteData로 쓰고 Attendance `DDDStorage`와 같은 `Projects/Core/FestiCoreStorage` 구성을 거친다.

| 역할 | 위치 |
| --- | --- |
| DB | `Interface/Database/AppDatabaseDependency` · `Sources/Shared/AppDatabaseMigrator` |
| 단순 값 | `Interface/Shared/PersistentSharedKey` · `Sources/Shared/SQLiteSharedValueStorage` |
| 조립 | `Sources/Factory/StorageFactory` · `Sources/DependencyValues+Storage` |

- 단순 값은 Attendance `AuthDomain/Interface/Sources/Entity/UserSessionSharedKey`처럼 `PersistentSharedKey`로 선언해 `@Shared`로 쓴다.
- 레코드는 Attendance `ScheduleDomain/Sources/Repository/Local/ScheduleLocalDataSource`처럼 `Sources/Repository/Local/<X>LocalDataSource`에서 `@Dependency(\.appDatabase)`로 저장한다.

## 레코드·계정별 데이터 이전

레코드·계정별 데이터의 이전은 Attendance `DDDStorage`와 같게 배치한다.

- 이전 코드는 `FestiCoreStorage/Sources/Legacy/LegacyUserDefaultsMigration`(Attendance `Sources/Legacy/LegacySwiftDataMigration`)에 두고, `Sources/Factory/StorageFactory`의 `prepareDatabase`에 `importLegacy` 훅(Attendance `prepareDatabase(importLegacy:)`)을 더해 `AppDatabaseMigrator` 다음에 실행한다.
- 레코드 표와 이전 기록 표(Attendance `legacyCacheImport`)는 `AppDatabaseMigrator`에서 만든다.
- 한 이전 단위의 레코드 쓰기와 완료·소유 계정 기록은 Attendance처럼 `database.write` 한 트랜잭션에서 하고 시작할 때 완료 기록을 확인해 건너뛴다. 실패하면 트랜잭션이 되돌아가 완료 기록이 남지 않으므로 다음 실행에서 다시 시도하며, 실패는 로그만 남기고 현재 DB를 메모리 DB로 바꾸지 않는다.
- 이전된 레코드의 계정 소유 확인은 `Interface/Database/LegacyCacheAccess`처럼 `isAllowed`·`markRefreshed`로 하고, LocalDataSource가 Attendance `ScheduleLocalDataSource`·`ProfileLocalDataSource`처럼 읽을 때 소유자가 현재 세션과 같은지 확인하고 서버 값으로 새로 저장한 뒤 소유 표시를 지운다.

## 이전 대상: FestivalDomain UserDefaults 저장소

`FestivalDomain/Sources`의 UserDefaults 저장소 다섯 개(`Bookmark/FestivalBookedStore+Live`, `Guide/FestivalGuideVisibilityStore+Live`, `PackDetail/FestivalPackLocalStore+Live`, `RecentSearch/FestivalRecentSearchStore+Live`, `Selection/FestivalSelectionStore+Live`)는 SQLiteData로 옮길 대상이다.

- 단순 값(`FestiCore.selectedFestivalID`, `FestiCore.hiddenFollowedFlagGuides`, `FestiCore.pack.autoDownloadOnWiFi`)은 `PersistentSharedKey`의 `legacyData`로 넘긴다.
- 레코드는 위 `LegacyUserDefaultsMigration`과 LocalDataSource로 옮긴다: `FestivalBookedStore`의 계정별 목록(`FestiCore.bookedFestivalIDs.user.<계정>`)과 계정별 이전 상태(소유자 없는 `legacyKey` 목록, `migrationOwnerKey`·`migrationDecisionKey`, `FestiCore.bookedFestivalIDs.eligible.<계정>`), `FestivalPackLocalStore`의 축제별 체크리스트(`FestiCore.pack.checklist.<축제>`), `FestivalRecentSearchStore`의 계정별·익명 목록(`FestiCore.festivalRecentSearches.user.<계정>`·`.anonymous`).
- 계정별 레코드는 소유 계정을 함께 옮긴다. `legacyKey` 목록은 지금 동작대로 결정 전에는 제안 대상으로 남기고, `migrationDecisionKey`가 `accepted`면 `migrationOwnerKey` 계정의 목록에 합치며, `declined`면 옮기지 않는다.
- 중복 실행·부분 실패·기존 값 없음에서도 결과가 같게 하고, 완료 기록과 보존 테스트를 확인한 뒤에만 원본 UserDefaults 키를 지운다.
- `FestiCoreStorage/Sources/Onboarding/FirstInstallOnboardingFileStore`는 Selection·Bookmark·RecentSearch 저장소의 키(`FestiCore.selectedFestivalID`, `FestiCore.bookedFestivalIDs*`, `FestiCore.festivalRecentSearches*`)로 업그레이드 사용자를 판별하므로, 이 키를 지우기 전에 이 판별을 이전된 DB 데이터나 이전 완료 표식 확인으로 바꾸고 완료 영수증 없는 업그레이드 사용자가 첫 설치 온보딩으로 가지 않는지 테스트한다.

`@Shared`와 `@Dependency`의 구분, LocalDataSource 주입 범위는 [Domain 모듈](domain-modules.md)을 따른다.
