import ComposableArchitecture
import FeatureAssembly
import TCAFlow

/// 마이 '기수이신가요?'에서 여는 기수 등록 흐름. 인증(S13 F~I) → 깃발 프로필(S10) → 기수 보드.
/// 첫 화면은 `BearerClaimDelegate.claimed`만 알리면 된다. 코드 입력을 QR 스캔으로 바꿔도 첫 화면만 갈아 끼우면 된다.
@FlowCoordinator(
  screen: "BearerEntryScreen",
  navigation: true
)
struct BearerEntryCoordinator {
  @ObservableState
  struct State: Equatable {
    var routes: [Route<BearerEntryScreen.State>]
    /// 기수 코드는 페스티벌마다 다르다.
    let festivalID: String
    let viewerUserID: String?

    init(
      festivalID: String,
      viewerUserID: String?
    ) {
      self.festivalID = festivalID
      self.viewerUserID = viewerUserID
      routes = [.root(
        .claim(BearerClaimFeature.State(festivalID: festivalID)),
        embedInNavigationView: true
      )]
    }
  }

  @CasePathable
  enum Action {
    case router(IndexedRouterActionOf<BearerEntryScreen>)
    case delegate(Delegate)
  }

  enum Delegate {
    /// 흐름을 닫는다(인증 화면 뒤로, 프로필 뒤로, 보드의 '관객 화면으로').
    case closeRequested
  }

  func handleRoute(
    state: inout State,
    action: Action
  ) -> Effect<Action> {
    switch action {
    case let .router(.routeAction(
      id: _,
      action: .claim(.delegate(.claimed(
        festivalID,
        claim
      )))
    )):
      guard !state.routes.contains(where: { $0.screen.is(\.profile) }) else { return .none }
      state.routes.push(.profile(BearerProfileFeature.State(
        festivalID: festivalID,
        flagID: claim.flagID,
        profile: claim.profile,
        isNewBearer: claim.isNew
      )))
      return .none

    case let .router(.routeAction(
      id: _,
      action: .profile(.delegate(.finished(flagID)))
    )):
      guard !state.routes.contains(where: { $0.screen.is(\.board) }) else { return .none }
      state.routes.push(.board(BearerBoardFeature.State(
        festivalID: state.festivalID,
        flagID: flagID,
        viewerUserID: state.viewerUserID
      )))
      return .none

    case .router(.routeAction(
      id: _,
      action: .claim(.delegate(.closeRequested))
    )),
      .router(.routeAction(
        id: _,
        action: .profile(.delegate(.closeRequested))
      )),
      .router(.routeAction(
        id: _,
        action: .board(.delegate(.closeRequested))
      )):
      // 등록을 마친 뒤 인증 화면으로 돌아가지 않도록 프로필·보드의 뒤로도 흐름을 닫는다.
      return .send(.delegate(.closeRequested))

    case .delegate, .router:
      return .none
    }
  }
}

extension BearerEntryCoordinator {
  @Reducer
  enum BearerEntryScreen {
    case claim(BearerClaimFeature)
    case profile(BearerProfileFeature)
    case board(BearerBoardFeature)
  }
}

extension BearerEntryCoordinator.BearerEntryScreen.State: Equatable {}
