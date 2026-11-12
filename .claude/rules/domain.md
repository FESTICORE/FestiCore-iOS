---
paths:
  - "Projects/Domain/**"
---

# Domain 경로 규칙

상세 문서: `docs/agent/domain-modules.md`, `docs/agent/dependency-injection.md`
구조 원본: Attendance_iOS `Projects/Domain/AttendanceDomain`(읽기 전용). 새 파일은 같은 역할 파일과 대조한다.

## Hard

- `Interface`와 `Sources`를 나눈다. `Interface/Sources/Entity`에 공개 값 · 오류, `Interface/Sources/<기능>`에 `Sendable` Repository · UseCase `*Interface` 계약 · Mock · `TestDependencyKey` · `DependencyValues` 접근자를 둔다.
- `Sources/<기능>`에 `<X>UseCaseImpl`, `Sources/Repository`에 `<X>RepositoryImpl`, `Sources/Model/DTO` · `Model/Mapper`에 DTO · Mapper, `Sources/<X>LiveDependencies.swift`에 `liveValue`를 둔다.
- Repository · UseCase 계약과 구현 위에는 역할과 경계를 설명하는 `///` 주석을 한두 줄 단다. (check-swift-conventions.py가 검사)
- UseCase 구현은 Repository Interface를 쓰고, Repository 구현은 공용 Network · Auth Interface를 주입받는다. 새 클라이언트나 토큰 저장소를 Domain마다 만들지 않는다.
- DTO → Entity, 도메인 값 → 요청 body 변환은 Domain Mapper가 맡는다.
- 로컬 레코드는 `Sources/Repository/Local/<X>LocalDataSource`에서 `@Dependency(\.appDatabase)`로 저장한다.
- 토큰 · 인가 코드 · 비밀 값은 로그와 테스트 실패 메시지에 넣지 않는다.

## Soft (기존 코드가 다르면 기존 코드를 따른다)

- 테스트는 요청의 실제 URL · method · 인증 · body, nullable DTO 매핑, 오류 전파를 확인한다.
- 새 테스트 타깃은 `Projects/App/Tests/FestiCore.xctestplan`에 추가한다.
