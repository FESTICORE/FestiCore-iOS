# SwiftUI View 패턴

## 화면 View

`Projects/Feature/Auth/Sources/Login/View/LoginView.swift`가 기준 예시다.

```swift
@ViewAction(for: LoginFeature.self)
public struct LoginView: View {
  @Bindable public var store: StoreOf<LoginFeature>

  public init(store: StoreOf<LoginFeature>) {
    self.store = store
  }

  public var body: some View { ... }
}

private extension LoginView {
  @ViewBuilder
  func socialLoginButton() -> some View { ... send(.signIn(.apple)) ... }
}

#Preview {
  LoginView(store: .init(initialState: LoginFeature.State()) { LoginFeature() })
}
```

- 화면 View는 store 하나만 받는다. 값·클로저 묶음을 init으로 받지 않는다.
- 하위 `<화면>/Components` View만 원시 값을 받는다. 자식 화면에는 scope한 store를 넘긴다.
- 타입 본문에는 저장 속성, 초기화, `body`만 둔다. 화면 섹션, 하위 뷰 빌더, UI 전용 계산 값과 액션 헬퍼는 같은 파일의 `private extension`에 둔다. 테스트가 접근하는 내부 헬퍼가 있으면 일반 `extension`에서 비공개 멤버에 각각 `private`를 붙인다. 외부에서 호출하는 체이닝 설정은 `public extension`에 둔다.
- 단일 View 조각은 계산 `var ...: some View`로 두고, 여러 View를 묶거나 분기하는 섹션은 `@ViewBuilder func ... -> some View`로 분리한다. 일반 계산 속성과 함수에는 명시적 `return`을 사용하되 결과 빌더는 Swift 문법을 따른다.
- 단일 View 조각의 계산 속성은 하나의 View를 반환한다. 형제 View 둘 이상은 `VStack` 등 컨테이너로 묶거나 `@ViewBuilder` 함수를 사용한다. View의 사용자 입력은 `send(.<View 액션>)`으로 보내고 `store.send` 또는 `inner`·`async`를 직접 보내지 않는다.

## DesignKit·SharedUI 컴포넌트 설정

- DesignKit·SharedUI 컴포넌트 생성자에는 콘텐츠와 필수 액션 같은 필수 내용만 둔다. 선택적 스타일·상태·옵션·동작은 `public extension`의 `func 설정(_ 값: 값타입) -> Self` 체이닝으로 제공한다.
- 체이닝 함수는 `var copy = self`로 사본을 만들고 해당 속성만 바꾼 뒤 반환한다. 화면에서는 `FCTab(selection: $selection, items: items).indicatorColor(color)`처럼 조합한다.
- 공용 컴포넌트의 기본값은 기존 화면을 유지하고, Figma 화면별 차이는 호출 화면에서 체이닝으로 지정한다. `FCTab`의 S00 라임색 밑줄과 `FCSearchResultRow`의 검색어 강조·임박 배지가 그 예다.

## 폴더

- `Sources/<화면>/Reducer`, `Sources/<화면>/View`, `Sources/<화면>/Components`, `Sources/<화면>/Model`, `Sources/Accessibility/<모듈>AccessibilityID.swift`
- 한 번만 쓰는 화면 섹션은 같은 파일의 extension에 둔다. 여러 Feature가 실제로 공유할 때만 SharedUI로 옮긴다. 로그인 시트처럼 한 기능의 화면은 그 Feature의 `View`에 둔다.
- 단순한 View에는 빈 extension을 만들지 않는다. View 분리만 하는 PR은 상태 전환, TCA 액션, 레이아웃, 접근성 동작을 바꾸지 않는다.

## 디자인과 상태

- 공통 색·서체·치수는 DesignKit 토큰을 쓴다. 라이트·다크, Dynamic Type, 화면 너비 변화를 실제 화면에서 확인한다.
- 비동기 로딩은 공용 `FCSkeletonView`와 관련 화면의 Skeleton 컴포넌트로 표시한다. 실패와 빈 상태는 별도 메시지와 재시도 동작으로 구분한다. 로딩이 아닌 nil 값을 무한 Skeleton으로 표시하지 않는다.
