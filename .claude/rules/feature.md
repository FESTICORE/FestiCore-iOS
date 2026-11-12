---
paths:
  - "Projects/Feature/**"
---

# Feature 경로 규칙

상세 문서: `docs/agent/tca-patterns.md`, `docs/agent/swiftui-patterns.md`, `docs/agent/popup-modal-system.md`, `docs/agent/tcaflow-navigation.md`, `docs/agent/dependency-injection.md`

## Hard

- Feature는 `<X>DomainInterface`의 UseCase와 시스템 의존성만 `@Dependency`로 주입받는다. Domain 구현(`import <X>Domain`), `API`, `APIEndpoint`, `FestiCoreNetwork*`, `FestiCoreAuth*`를 import하지 않는다. 조립은 `FeatureAssembly`만 한다. (verify의 check-boundaries가 검사)
- Feature가 쓰는 공개 값 타입은 Feature `Model`이 아니라 Domain `Interface/Sources/Entity`에 둔다.
- 화면 하나에 `@Reducer` 하나. 액션은 `view` · `async` · `inner` · `delegate`로 나누고 `extension`의 `handle*Action` 함수로 처리한다.
- 화면 View는 `@ViewAction`을 붙이고 store 하나만 받는다. 확인 팝업은 `fcAlert`, 바텀시트는 `fcModal`로 띄운다.
- View 타입 본문에는 저장 속성 · 초기화 · `body`만 두고 섹션은 같은 파일의 `private extension <View>`로 뺀다.
- 값을 반환하는 일반 함수 · 계산 속성에는 `return`을 쓴다. 파라미터 · 인자가 2개 이상이면 한 줄에 하나씩 쓴다. (훅의 check-swift-conventions.py가 검사)
- 유한한 단계 · 상호 배타적인 선택은 enum으로 표현한다.

## Soft (기존 코드가 다르면 기존 코드를 따른다)

- 비동기 데이터 화면은 로딩 · 실패 · 빈 상태를 나누고 공용 Skeleton을 쓴다.
- `State` 저장 속성이 많아지면 함께 변하는 값을 하위 상태나 표시 Model로 묶는다.
- Reducer 테스트는 Swift Testing + `TestStore`로 쓰고 필요한 의존성을 명시적으로 주입한다.
