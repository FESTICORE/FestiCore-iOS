---
paths:
  - "Projects/App/**"
  - "Projects/Extension/**"
---

# App · Extension 경로 규칙

상세 문서: `docs/agent/tcaflow-navigation.md`, `docs/agent/dependency-injection.md`, `AGENTS.md`의 딥링크 · 푸시 항목

## Hard

- 앱은 `FestiCoreApp`에서 `AppCoordinator` Store를 만들고, 루트 화면 전환은 `AppCoordinator.State`의 enum case가 맡는다.
- 앱은 개별 Feature 구현을 import하지 않는다. `FeatureAssembly`가 공개한 것과 `<X>Interface`만 쓴다. (check-boundaries가 검사)
- 앱 시작점에서 의존성을 전역 등록하지 않는다. 앱 호스팅 단위 테스트는 루트 Store의 자동 시작 효과를 실행하지 않고, 필요한 의존성을 테스트마다 명시적으로 주입한다. 미등록 이슈를 무음 처리하지 않는다.
- 딥링크 경로는 `FestiCoreDeeplink` enum 하나로 정의하고 파싱(`FestiCoreUtility`) · 대기(`PendingDeeplinkStore`) · URL 전달(`AppDeeplinkBridge`) · 라우팅(`AppCoordinator`)을 나눈다.
- 표시 푸시는 `mutable-content`로 `Extension/FestiCoreNotificationService`를 거치고, 무음 동기화는 `content-available`로 `AppDelegate`에서 처리한다.
- `GoogleService-Info.plist` · 자격 증명 · 로컬 설정을 추적 파일에 넣지 않는다.

## Soft (기존 코드가 다르면 기존 코드를 따른다)

- 앱 변경 검증은 `./make test -only-testing:FestiCoreTests`(verify가 자동 선택)로 하고 UI 테스트 · 실기기 검증과 구분해 보고한다.
