# TCA 패턴

## 리듀서 구성

Attendance(`Projects/Feature/Management/Sources/StaffMain/Reducer/StaffFeature.swift`)와 같은 구성을 따른다. 이 저장소에서는 `Projects/Feature/Auth/Sources/Login/Reducer/LoginFeature.swift`가 기준 예시다.

- 파일 순서: `init` → `@ObservableState State` → `Action` → 액션별 enum → `@Dependency` → `body` → `extension <Feature>`의 처리 함수.
- `Action: ViewAction`은 `view`·`async`·`inner`·`delegate`로 나눈다. 바인딩이 있으면 `binding`, 띄우는 화면이 있으면 `destination(PresentationAction<Destination.Action>)`을 추가한다. 자식 Feature 액션은 `case vote(VoteFeature.Action)`처럼 최상위 case로 두고 `scope(...)` 같은 묶음 case를 만들지 않는다. 액션 enum마다 `// MARK:`를 단다.
  - `view`: 사용자 입력
  - `async`: 효과를 시작하는 요청
  - `inner`: 효과 결과와 내부 전이
  - `delegate`: 부모에게 알리는 결과. 계약은 `Interface/Sources/<X>Delegate.swift`에 두고 `typealias DelegateAction = <X>Delegate`로 받는다.
- `body`는 액션 종류만 나눈다(`case .view(let action): return handleViewAction(state: &state, action: action)`). 처리는 같은 파일 `extension <Feature>`의 `private func handleViewAction`·`handleAsyncAction`·`handleInnerAction`·`handleDelegateAction`에 둔다. 자식·`destination` 액션 중 부모가 받을 것만 `body`에서 직접 매칭하고 나머지는 `default: return .none`으로 둔다. 자식은 `Scope(\.child, action: \.child)`로 연결한다.
- `.run` 효과는 async 핸들러에서 시작한다. view 핸들러는 중복 입력 가드와 상태 변경 뒤 `.send(.async(...))`로 넘긴다.
- 취소·중복 요청 정책은 `CancelID`로 명시한다.
- `State`에 저장 속성이 많으면 같은 화면 책임으로 함께 변하는 값을 하위 상태 타입으로 묶는다. 화면 전용 로딩과 표시 값은 Feature의 State/Model에, 공개 업무 값은 Domain Entity에 둔다. 상태를 이동한 뒤 `TestStore`로 전이·취소·재시도를 확인한다.
- 유한한 단계와 상호 배타적인 상태는 여러 불리언 대신 enum으로 표현한다. `view` 액션은 View의 `send`에서 시작해 Reducer의 `handleViewAction`에서 처리한다.

## 화면과 리듀서

- 한 화면에는 리듀서 하나와 View 하나를 둔다. 여러 화면이 리듀서 하나를 공유하거나, 같은 리듀서를 다른 화면으로 다시 push하지 않는다.
- 시트·모달·알림으로 띄우는 화면은 `@Reducer enum Destination`과 `@Presents var destination`으로 들고 `.ifLet(\.$destination, action: \.destination)`로 합친다. 띄우는 화면이 하나뿐이면 `@Presents var child`와 `.ifLet(\.$child, action: \.child)`도 쓸 수 있다.
- 부모는 자식 상태를 직접 쓰지 않는다. 자식에 알릴 명령은 Attendance처럼 자식의 `view` 액션으로 보낸다(예: `.send(.vote(.view(.requestExit)))`). 자식의 `inner`는 자식 내부 결과 처리용이라 부모가 보내지 않는다. 자식의 결과는 `delegate`로 받는다.

## 의존성

- Feature 리듀서는 Domain UseCase와 시스템 의존성(`date`·`continuousClock`·`mainQueue`)만 `@Dependency`로 주입한다.
- Service·Store·Client는 Domain UseCase로 감싼다. Feature나 App 코디네이터에서 직접 주입하지 않는다.

## 화면 전용 값의 위치

- 정렬·필터·개수 같은 파생 값은 State의 계산 속성이나 리듀서 파일의 `extension <Feature>.State`에 둔다.
- 표시 모델 struct는 `<화면>/Model`에, 색·문구 매핑은 View의 `private extension`에 둔다.
- 정적 함수만 모은 `<X>Presentation` 같은 헬퍼 enum이나, 이름만 UseCase인 순수 함수 파일을 Feature에 만들지 않는다.
- DEBUG 샘플 데이터는 Tests 타깃에 둔다. `#Preview`는 `State()`나 간단한 초기값으로 만든다.

## 테스트

Reducer 테스트에서 상태 전이와 Effect 결과를 `TestStore`로 확인한다. async 단계도 `receive`로 확인한다.
