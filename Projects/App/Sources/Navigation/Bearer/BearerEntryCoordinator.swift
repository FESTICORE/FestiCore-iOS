import ComposableArchitecture
import FeatureAssembly
import TCAFlow

/// 기수 등록 흐름. 코드 없는 등록은 (가입 직후면 기수 여부 S14 C →) 깃발 프로필 등록(S14 D) → 저장 완료(S14 E),
/// 코드 인증은 인증(S13 F~I) → 깃발 프로필(S10, 오늘 계획 고르기) → 기수 보드다.
/// 코드 화면은 `BearerClaimDelegate.claimed`만 알리면 된다. 코드 입력을 QR 스캔으로 바꿔도 그 화면만 갈아 끼우면 된다.
@FlowCoordinator(
  screen: "BearerEntryScreen",
  navigation: true
)
struct BearerEntryCoordinator {
  @ObservableState
  struct State: Equatable {
    var routes: [Route<BearerEntryScreen.State>]
    /// 기수 코드는 페스티벌마다 다르다. 코드 없는 등록은 고른 페스티벌로 정한다.
    var festivalID: String?
    let viewerUserID: String?
    /// 기수 여부 다음에 여는 등록 화면이 먼저 고를 페스티벌
    var preferredFestivalID: String?

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

    /// 마이 내 깃발(More D)에서 이미 기수인 깃발의 프로필 수정(S10)이나 기수 보드(S09)를 바로 연다.
    init(
      festivalID: String,
      flagID: String,
      viewerUserID: String?,
      opensBoard: Bool
    ) {
      self.festivalID = festivalID
      self.viewerUserID = viewerUserID
      let root: BearerEntryScreen.State = opensBoard
        ? .board(BearerBoardFeature.State(
          festivalID: festivalID,
          flagID: flagID,
          viewerUserID: viewerUserID
        ))
        : .profile(BearerProfileFeature.State(
          festivalID: festivalID,
          flagID: flagID
        ))
      routes = [.root(
        root,
        embedInNavigationView: true
      )]
    }

    /// 코드 없는 등록. 가입 직후(S14 케이스 1·2)에는 기수 여부부터 묻는다.
    init(
      registerPreferredFestivalID preferredFestivalID: String?,
      viewerUserID: String?,
      asksRole: Bool
    ) {
      festivalID = nil
      self.viewerUserID = viewerUserID
      let root: BearerEntryScreen.State = asksRole
        ? .roleChoice(BearerRoleChoiceFeature.State())
        : .register(BearerRegisterFeature.State(preferredFestivalID: preferredFestivalID))
      routes = [.root(
        root,
        embedInNavigationView: true
      )]
      self.preferredFestivalID = preferredFestivalID
    }
  }

  @CasePathable
  enum Action {
    case router(IndexedRouterActionOf<BearerEntryScreen>)
    case delegate(Delegate)
  }

  @CasePathable
  enum Delegate: Equatable {
    /// 흐름을 닫는다(인증 화면 뒤로, 프로필 뒤로, 보드의 '관객 화면으로').
    case closeRequested
    /// 코드 없이 깃발을 만들었다. 부모가 그 페스티벌을 핀(선택 저장)한다.
    case festivalPinRequested(String)
    /// 저장 완료의 '팩 받기'. 부모가 흐름을 닫고 그 페스티벌 라이브 보드를 연다.
    case packRequested(String)
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
      guard !state.routes.contains(where: { $0.screen.is(\.board) }),
            let festivalID = state.festivalID else { return .none }
      state.routes.push(.board(BearerBoardFeature.State(
        festivalID: festivalID,
        flagID: flagID,
        viewerUserID: state.viewerUserID
      )))
      return .none

    case .router(.routeAction(
      id: _,
      action: .profile(.delegate(.planRequested))
    )):
      guard !state.routes.contains(where: { $0.screen.is(\.planPick) }),
            let profile = state.routes.last(where: { $0.screen.is(\.profile) })?.screen.profile else { return .none }
      state.routes.push(.planPick(BearerPlanPickFeature.State(
        sets: profile.sets,
        plan: profile.plan
      )))
      return .none

    case let .router(.routeAction(
      id: _,
      action: .planPick(.delegate(.picked(plan)))
    )):
      state.routes.removeAll { $0.screen.is(\.planPick) }
      guard let profileIndex = state.routes.lastIndex(where: { $0.screen.is(\.profile) }) else { return .none }
      return .send(.router(.routeAction(
        id: profileIndex,
        action: .profile(.view(.planChanged(plan)))
      )))

    case .router(.routeAction(
      id: _,
      action: .planPick(.delegate(.closeRequested))
    )):
      state.routes.removeAll { $0.screen.is(\.planPick) }
      return .none

    case .router(.routeAction(
      id: _,
      action: .roleChoice(.delegate(.bearerChosen))
    )):
      guard !state.routes.contains(where: { $0.screen.is(\.register) }) else { return .none }
      state.routes.push(.register(BearerRegisterFeature.State(preferredFestivalID: state.preferredFestivalID)))
      return .none

    case let .router(.routeAction(
      id: _,
      action: .register(.delegate(.registered(
        _,
        festivalID
      )))
    )):
      state.festivalID = festivalID
      return .send(.delegate(.festivalPinRequested(festivalID)))

    case let .router(.routeAction(
      id: _,
      action: .register(.delegate(.packRequested(festivalID)))
    )):
      return .send(.delegate(.packRequested(festivalID)))

    case let .router(.routeAction(
      id: _,
      action: .register(.delegate(.claimRequested(festivalID)))
    )):
      guard !state.routes.contains(where: { $0.screen.is(\.claim) }) else { return .none }
      state.festivalID = festivalID
      state.routes.push(.claim(BearerClaimFeature.State(festivalID: festivalID)))
      return .none

    case .router(.routeAction(
      id: _,
      action: .claim(.delegate(.closeRequested))
    )):
      // 코드 없는 등록에서 들어온 코드 인증은 뒤로 가면 등록 화면으로 돌아간다.
      if state.routes.count > 1, state.routes.last?.screen.is(\.claim) == true {
        state.routes.goBack()
        return .none
      }
      return .send(.delegate(.closeRequested))

    case .router(.routeAction(
      id: _,
      action: .roleChoice(.delegate(.audienceChosen))
    )),
      .router(.routeAction(
        id: _,
        action: .roleChoice(.delegate(.closeRequested))
      )),
      .router(.routeAction(
        id: _,
        action: .register(.delegate(.finished))
      )),
      .router(.routeAction(
        id: _,
        action: .register(.delegate(.closeRequested))
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
    case roleChoice(BearerRoleChoiceFeature)
    case register(BearerRegisterFeature)
    case claim(BearerClaimFeature)
    case profile(BearerProfileFeature)
    case planPick(BearerPlanPickFeature)
    case board(BearerBoardFeature)
  }
}

extension BearerEntryCoordinator.BearerEntryScreen.State: Equatable {}
