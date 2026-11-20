---
name: tca-feature
description: FestiCore iOS 화면을 TCA로 만들거나 고칠 때 사용한다. Feature 모듈 만들기(./make module Feature), Reducer State · Action(view · async · inner · delegate) 구성, extension의 handle*Action 함수, Domain Interface UseCase를 @Dependency로 쓰기, @ViewAction View 연결, Swift Testing + TestStore 테스트. Projects/Feature · Projects/App의 Reducer · View를 고칠 때 쓴다. 화면 사이 이동은 screen-flow, 모듈 · 의존 설정은 tuist 스킬. 완료 체크리스트(checklist.md)로 스스로 검증한다.
---

# iOS 화면 (TCA)

규칙 원본: `.claude/docs/ios-tca.md` · `.claude/docs/swiftui-patterns.md` · `.claude/docs/dependency-injection.md` · `.claude/rules/feature.md`. 다르면 문서가 우선이다.
실제 예: `Projects/Feature/Auth/Sources/Login/Reducer/LoginFeature.swift` · `View/LoginView.swift` · `Tests/Sources/LoginFeatureTests.swift`. 구성 원본은 Attendance `Projects/Feature/Management/Sources/StaffMain/Reducer/StaffFeature.swift`다.

## 0. 시작 전

- 동작이 바뀌면 spec을 먼저 쓴다(`spec-first`). 테스트는 spec의 규칙에서 나온다.
- 쓸 UseCase가 `Projects/Domain/<기능>Domain/Interface`에 있는지 확인한다. 없으면 Domain에 먼저 만든다(`.claude/docs/domain-modules.md`).

## 1. 모듈

```bash
./make module Feature Profile    # Projects/Feature/Profile, Modules.swift case 등록
./make generate
```

다른 Feature · 부모가 볼 타입(`<X>Delegate`, 진입 인자)만 `Interface/Sources`에 둔다. 앱에는 `FeatureAssembly`로 공개한다. 폴더는 `Sources/<화면>/{Reducer,View,Components,Model}`.

## 2. Reducer

파일 순서: `init` → `@ObservableState State` → `Action` → 액션별 enum → `@Dependency` → `body` → `extension <Feature>`의 처리 함수.

```swift
@Reducer
public struct LoginFeature {
  public init() {}

  @ObservableState
  public struct State: Equatable {
    public var isSigningIn = false
    public init() {}
  }

  @CasePathable
  public enum Action: ViewAction, Equatable {
    case view(View)
    case async(AsyncAction)
    case inner(InnerAction)
    case delegate(DelegateAction)
  }

  // MARK: - ViewAction

  @CasePathable
  public enum View: Equatable {
    case signIn(OAuthProvider)
  }

  // MARK: - AsyncAction

  @CasePathable
  public enum AsyncAction: Equatable {
    case signIn(OAuthProvider)
  }

  // MARK: - InnerAction

  @CasePathable
  public enum InnerAction: Equatable {
    case signInSucceeded(AuthLoginResult)
    case signInFailed(AuthDomainError)
  }

  // MARK: - DelegateAction

  public typealias DelegateAction = LoginDelegate   // 계약은 Interface/Sources/LoginDelegate.swift

  @Dependency(\.oauthUseCase) private var oauthUseCase

  public var body: some ReducerOf<Self> {
    Reduce { state, action in
      switch action {
      case .view(let viewAction):
        return handleViewAction(state: &state, action: viewAction)
      case .async(let asyncAction):
        return handleAsyncAction(state: &state, action: asyncAction)
      case .inner(let innerAction):
        return handleInnerAction(state: &state, action: innerAction)
      case .delegate:
        return .none
      }
    }
  }
}

extension LoginFeature {
  private func handleViewAction(
    state: inout State,
    action: View
  ) -> Effect<Action> {
    switch action {
    case .signIn(let provider):
      guard !state.isSigningIn else { return .none }
      state.isSigningIn = true
      return .send(.async(.signIn(provider)))
    }
  }

  private func handleAsyncAction(
    state: inout State,
    action: AsyncAction
  ) -> Effect<Action> {
    switch action {
    case .signIn(let provider):
      return .run { send in
        do {
          let result = try await oauthUseCase.signIn(provider: provider)
          await send(.inner(.signInSucceeded(result)))
        } catch let error as AuthDomainError {
          await send(.inner(.signInFailed(error)))
        } catch {
          await send(.inner(.signInFailed(.providerFailure)))
        }
      }
    }
  }

  private func handleInnerAction(
    state: inout State,
    action: InnerAction
  ) -> Effect<Action> {
    switch action {
    case .signInSucceeded(let result):
      state.isSigningIn = false
      return .send(.delegate(.signedIn(result)))

    case .signInFailed:
      state.isSigningIn = false
      return .none
    }
  }
}
```

- 값을 반환하는 함수 · 계산 속성에는 `return`을 쓴다. 파라미터 · 인자가 2개 이상이면 한 줄에 하나씩 쓴다(`.claude/docs/code-convention.md`, `check-swift-conventions.py`가 검사).
- 바인딩이 있으면 `binding`, 띄우는 화면이 있으면 `destination(PresentationAction<Destination.Action>)`을 더한다. 자식 Feature 액션은 최상위 case(`case vote(VoteFeature.Action)`)로 둔다. 쓰지 않는 case는 만들지 않는다.
- `.run`은 async 핸들러에서 시작한다. view 핸들러는 중복 입력 가드와 상태 변경 뒤 `.send(.async(...))`로 넘긴다. 취소 · 중복 정책은 `CancelID`로 명시한다.
- `@Dependency`는 Domain UseCase Interface와 시스템 의존성(`date` · `continuousClock` · `mainQueue`)만 쓴다. Service · Store · Client · Domain 구현 · `API` · `APIEndpoint`를 주입하거나 import하지 않는다.
- 부모에게 알릴 일은 `.delegate`로 보낸다. 이동은 부모 Coordinator가 정한다(`screen-flow`). 부모는 자식의 `view` 액션으로 명령하고 자식 `inner`를 보내지 않는다.
- 유한한 단계 · 상호 배타적인 선택은 enum으로 둔다. State 저장 속성이 많아지면 함께 변하는 값을 하위 상태 · 표시 Model로 묶는다.

## 3. View

```swift
@ViewAction(for: LoginFeature.self)
public struct LoginView: View {
  @Bindable public var store: StoreOf<LoginFeature>

  public init(store: StoreOf<LoginFeature>) {
    self.store = store
  }

  public var body: some View {
    socialLoginButton()
  }
}

private extension LoginView {
  @ViewBuilder
  func socialLoginButton() -> some View {
    Button("Apple로 로그인") { send(.signIn(.apple)) }
      .disabled(store.isSigningIn)
  }
}
```

- 화면 View는 store 하나만 받는다. 타입 본문에는 저장 속성 · 초기화 · `body`만 두고 섹션은 `private extension`에 둔다.
- 입력은 `send(.<View 액션>)`으로 보낸다. `store.send`나 `inner` · `async`를 직접 보내지 않는다.
- 확인 팝업은 `fcAlert`, 바텀시트는 `fcModal`(`.claude/docs/popup-modal-system.md`). 비동기 데이터는 로딩 · 실패 · 빈 상태를 나누고 공용 Skeleton을 쓴다.

## 4. 테스트 (Swift Testing + TestStore)

```swift
struct LoginFeatureTests {
  @Test @MainActor func closeTapAsksParentToDismissSheet() async {
    let store = TestStore(initialState: LoginFeature.State()) { LoginFeature() }

    await store.send(.view(.closeTapped))
    await store.receive(.delegate(.closeRequested))
  }
}
```

- 의존성은 `withDependencies`로 테스트마다 명시적으로 주입한다. 실제 네트워크 · Keychain을 쓰지 않고, 기본 Mock의 미주입 이슈를 무음 처리하지 않는다.
- 상태 전이 · 취소 · 재시도와 async 단계의 `receive`를 확인한다.
- 새 테스트 타깃은 `Projects/App/Tests/FestiCore.xctestplan`에 추가한다.

## 5. 확인 · 완료 체크리스트

`checklist.md`의 항목을 하나씩 증거(명령 · 종료 코드 · 파일 경로)와 함께 확인한다. 하나라도 못 채우면 완료로 보고하지 않고 무엇이 남았는지 보고한다.

작업 중 틀렸다는 지적을 받으면 채팅에서 고치고 끝내지 않는다. 같은 PR에서 원인이 된 문서 · 이 스킬 · `checklist.md`를 고친다.


```bash
python3 .claude/hooks/check-swift-conventions.py <바꾼 Swift 파일...>
.claude/scripts/verify          # boundaries · swift-conventions · generate · test
```
