import AuthInterface
import ComposableArchitecture
import FeatureAssembly
import TCAFlow

@FlowCoordinator(
  screen: "SignUpScreen",
  navigation: true
)
struct SignUpFlowCoordinator {
  @ObservableState
  struct State: Equatable {
    var routes: [Route<SignUpScreen.State>]

    init(signUp: SignUpFeature.State = .init()) {
      routes = [.root(
        .signUp(signUp),
        embedInNavigationView: true
      )]
    }

    var signUp: SignUpFeature.State {
      get {
        guard let root = routes.first, case let .signUp(signUp) = root.screen else {
          preconditionFailure("회원가입 흐름에는 가입 화면이 루트로 있어야 합니다")
        }
        return signUp
      }
      set {
        guard !routes.isEmpty, routes[0].screen.is(\.signUp) else {
          preconditionFailure("회원가입 흐름에는 가입 화면이 루트로 있어야 합니다")
        }
        routes[0].screen = .signUp(newValue)
      }
    }

    mutating func resetNavigation() {
      routes.removeAll { !$0.screen.is(\.signUp) }
    }
  }

  @CasePathable
  enum Action {
    case router(IndexedRouterActionOf<SignUpScreen>)
    case view(SignUpFeature.View)
    case delegate(SignUpDelegate)
  }

  func handleRoute(
    state: inout State,
    action: Action
  ) -> Effect<Action> {
    switch action {
    case .view(.sheetClosed):
      state.resetNavigation()
      return .send(.router(.routeAction(
        id: 0,
        action: .signUp(.view(.sheetClosed))
      )))

    case let .view(view):
      return .send(.router(.routeAction(
        id: 0,
        action: .signUp(.view(view))
      )))

    case let .router(.routeAction(
      id: _,
      action: .signUp(.delegate(.legalDocumentRequested(
      url,
      title
    )))
    )):
      guard !state.routes.contains(where: { $0.screen.is(\.legalDocument) }) else { return .none }
      state.routes.push(.legalDocument(.init(
        url: url,
        title: title
      )))
      return .none

    case let .router(.routeAction(
      id: _,
      action: .signUp(.delegate(.submitRequested(submission)))
    )):
      return .send(.delegate(.submitRequested(submission)))

    case .router(.routeAction(
      id: _,
      action: .signUp(.delegate(.closeRequested))
    )):
      return .send(.delegate(.closeRequested))

    case .router(.routeAction(
      id: _,
      action: .legalDocument(.delegate(.backToRoot))
    )):
      state.routes.goBack()
      return .none

    case .delegate, .router:
      return .none
    }
  }
}

extension SignUpFlowCoordinator {
  @Reducer
  enum SignUpScreen {
    case signUp(SignUpFeature)
    case legalDocument(WebFeature)
  }
}

extension SignUpFlowCoordinator.SignUpScreen.State: Equatable {}
