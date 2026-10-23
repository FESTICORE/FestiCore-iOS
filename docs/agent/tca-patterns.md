# TCA 패턴

`Tuist/Package.swift`는 Composable Architecture를 의존성으로 선언한다. `Projects/Feature/Home/Sources/HomeFeature.swift`가 Home 상태와 액션을 소유하고, `FestiCoreHomeView`는 `StoreOf<HomeFeature>`를 받는다. 새 기능에 TCA를 적용할 때 다음 순서로 작업한다.

1. 기능 상태, 사용자 동작, 외부 응답을 분리해 정의한다.
2. 비동기 작업은 취소와 중복 요청 정책을 정한다.
3. 앱이 필요한 의존성만 기능에 주입한다. 네트워크 클라이언트의 구체 구현을 View에 넣지 않는다.
4. Reducer 테스트에서 상태 전이와 Effect 결과를 확인한다.

실제 기능이 추가되면 이 문서를 그 기능 코드와 함께 갱신한다.
