import ComposableArchitecture

@Reducer
public struct OnboardingFeature {
  @ObservableState
  public struct State: Equatable {
    public var page = 0

    public init() {}
  }

  public enum Action: ViewAction {
    case view(View)
    case delegate(DelegateAction)
  }

  @CasePathable
  public enum View {
    case pageChanged(Int)
    case nextTapped
    case skipTapped
  }

  @CasePathable
  public enum DelegateAction {
    case completed
  }

  public init() {}

  public var body: some ReducerOf<Self> {
    Reduce { state, action in
      switch action {
      case let .view(viewAction):
        return handleViewAction(state: &state, action: viewAction)
      case .delegate:
        return .none
      }
    }
  }
}

private extension OnboardingFeature {
  func handleViewAction(state: inout State, action: View) -> Effect<Action> {
    switch action {
    case let .pageChanged(page):
      state.page = min(max(page, 0), OnboardingPage.all.count - 1)
      return .none
    case .nextTapped:
      guard state.page < OnboardingPage.all.count - 1 else {
        return .send(.delegate(.completed))
      }
      state.page += 1
      return .none
    case .skipTapped:
      return .send(.delegate(.completed))
    }
  }
}
