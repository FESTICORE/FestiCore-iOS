import ComposableArchitecture
import FeatureAssembly
import Foundation
import TCAFlow

/// 마이 화면과 상세 목적지의 상태 변경을 소유하며 라우터 액션을 Feature에 전달한다.
/// 기수 설정 흐름은 마이 경로 위에 이어 push하고, 그 화면 액션은 `BearerEntryCoordinator`로 넘긴다.
@Reducer
struct ProfileCoordinator {
  @ObservableState
  @dynamicMemberLookup
  struct State: Equatable {
    /// 스택 루트인 마이 화면과 그 상세 목적지
    var root = ProfileFeature.State()
    /// 마이에서 연 기수 설정 흐름. 마이 경로 위에 push로 보인다.
    var bearer: BearerEntryCoordinator.State?

    subscript<Value>(dynamicMember keyPath: WritableKeyPath<ProfileFeature.State, Value>) -> Value {
      get { return root[keyPath: keyPath] }
      set { root[keyPath: keyPath] = newValue }
    }

    subscript<Value>(dynamicMember keyPath: KeyPath<ProfileFeature.State, Value>) -> Value {
      return root[keyPath: keyPath]
    }
  }

  @CasePathable
  enum Action {
    case router(IndexedRouterActionOf<ProfileScreen>)
    case profile(ProfileFeature.Action)
    case bearer(BearerEntryCoordinator.Action)
  }

  var body: some ReducerOf<Self> {
    Scope(
      state: \.root,
      action: \.profile
    ) {
      ProfileFeature()
    }

    Reduce { state, action in
      switch action {
      case let .router(.routeAction(
        id: id,
        action: .bearer(childAction)
      )):
        return .send(.bearer(.router(.routeAction(
          id: id - state.root.profileRoutes.count,
          action: childAction
        ))))

      case let .router(.routeAction(
        id: id,
        action: .profile(childAction)
      )) where id == 0:
        return .send(.profile(childAction))

      case let .router(.routeAction(
        id: id,
        action: .packDetail(childAction)
      )) where id == 1:
        return .send(.profile(.destination(.presented(.packDetail(childAction)))))

      case let .router(.routeAction(
        id: id,
        action: .settings(childAction)
      )) where id == 1:
        return .send(.profile(.destination(.presented(.settings(childAction)))))

      case let .router(.routeAction(
        id: id,
        action: .account(childAction)
      )) where id == 2:
        return sendToSettings(.destination(.presented(.account(childAction))))

      case let .router(.routeAction(
        id: id,
        action: .appearance(childAction)
      )) where id == 2:
        return sendToSettings(.destination(.presented(.appearance(childAction))))

      case let .router(.routeAction(
        id: id,
        action: .legalDocument(childAction)
      )) where id == 2:
        return sendToSettings(.destination(.presented(.legalDocument(childAction))))

      case let .router(.routeAction(
        id: id,
        action: .lockScreen(childAction)
      )) where id == 2:
        return sendToSettings(.destination(.presented(.lockScreen(childAction))))

      case let .router(.routeAction(
        id: id,
        action: .noticeList(childAction)
      )) where id == 2:
        return sendToSettings(.destination(.presented(.noticeList(childAction))))

      case let .router(.routeAction(
        id: id,
        action: .noticeDetail(childAction)
      )) where id == 3:
        guard state.destination?.settings?.destination?.noticeList?.destination?.detail != nil else { return .none }
        return sendToSettings(.destination(.presented(.noticeList(
          .destination(.presented(.detail(childAction)))
        ))))

      case let .router(.routeAction(
        id: id,
        action: .notifications(childAction)
      )) where id == 2:
        return sendToSettings(.destination(.presented(.notifications(childAction))))

      case let .router(.updateRoutes(routes)):
        guard state.bearer == nil else {
          return handleBearerUpdatedRoutes(
            state: &state,
            routes: routes
          )
        }
        return handleUpdatedRoutes(
          state: state,
          routes: routes
        )

      case .router, .profile, .bearer:
        return .none
      }
    }
    .ifLet(
      \.bearer,
      action: \.bearer
    ) {
      BearerEntryCoordinator()
    }
  }
}

extension ProfileCoordinator {
  /// 설정 홈 아래 화면의 입력을 설정 홈 Feature로 보낸다.
  private func sendToSettings(_ action: SettingsHomeFeature.Action) -> Effect<Action> {
    return .send(.profile(.destination(.presented(.settings(action)))))
  }

  /// 기수 화면을 뒤로 밀면 남은 화면만 두고, 모두 사라지면 흐름을 닫고 내 깃발을 다시 읽는다.
  private func handleBearerUpdatedRoutes(
    state: inout State,
    routes: [Route<ProfileScreen.State>]
  ) -> Effect<Action> {
    let remaining = routes.count - state.root.profileRoutes.count
    guard remaining > 0 else {
      state.bearer = nil
      return .send(.profile(.view(.bearerFlagsRefreshRequested)))
    }
    state.bearer?.keepRoutes(remaining)
    return .none
  }

  /// 뒤로 밀어 줄어든 경로에 맞춰 가장 위에서 사라진 목적지만 닫는다.
  private func handleUpdatedRoutes(
    state: State,
    routes: [Route<ProfileScreen.State>]
  ) -> Effect<Action> {
    guard state.destination != nil, state.destination?.alert == nil else { return .none }
    if routes.count == 1 {
      return .send(.profile(.destination(.dismiss)))
    }
    guard let settings = state.destination?.settings else { return .none }
    if routes.count == 2, settings.destination != nil, settings.destination?.alert == nil {
      return sendToSettings(.destination(.dismiss))
    }
    if settings.destination?.noticeList?.destination?.detail != nil,
       !routes.contains(where: { $0.screen.is(\.noticeDetail) }) {
      return sendToSettings(.destination(.presented(.noticeList(.destination(.dismiss)))))
    }
    return .none
  }
}
