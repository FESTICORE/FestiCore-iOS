---
paths:
  - "Projects/Service/**"
  - "Projects/Core/**"
---

# Service · Core 경로 규칙

상세 문서: `docs/agent/domain-modules.md`, `docs/agent/dependency-injection.md`, `AGENTS.md`의 "통신과 Domain 모듈"

## Hard

- API 경로는 `Service/API`, `FestiCoreDataRequest` 요청은 `Service/APIEndpoint`에 둔다. 요청마다 path · HTTP method · authorization · `Encodable & Sendable` body · 재시도 정책을 명시한다.
- `APIEndpoint`는 Domain · Auth Service(`FestiCoreAuth*`)에 의존하지 않는다. (check-boundaries가 검사)
- 공개 로그인 · 토큰 갱신은 `.none`, 로그아웃은 `.automatic`. 인증 요청은 응답 DTO를 명시해 `send(_:as:)`로 보낸다.
- HTTP · WebSocket은 `Core/FestiCoreNetwork`의 Alamofire 구조(SessionFactory · NetworkClient · 인터셉터 · EventMonitor · 로그 보호 · 재시도 정책) 안에 둔다. 이 구조 밖에 새 통신 코드를 만들지 않는다. 멱등하지 않은 메시지는 자동 재전송하지 않는다.
- 앱 내부 DB는 `Core/FestiCoreStorage`(SQLiteData)를 거친다. 표는 `AppDatabaseMigrator`에서 만들고, 단순 값은 `PersistentSharedKey`로 선언해 `@Shared`로 쓴다.
- Sentry · Mixpanel 코드는 `Service/FestiCoreAnalytics`에만 둔다. (check-boundaries가 검사)
- 인터페이스는 Interface 타깃, `liveValue`는 구현 · 조립 모듈에 둔다. 런타임 DI 컨테이너 · WeaveDI를 쓰지 않는다.

## Soft (기존 코드가 다르면 기존 코드를 따른다)

- 이전(legacy) 코드는 `FestiCoreStorage/Sources/Legacy`에 두고 한 이전 단위는 `database.write` 한 트랜잭션으로 쓴다.
