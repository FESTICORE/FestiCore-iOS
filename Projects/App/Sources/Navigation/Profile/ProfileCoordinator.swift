import ComposableArchitecture
import FeatureAssembly
import Foundation
import TCAFlow

/// 마이 화면과 상세 목적지의 상태 변경을 소유하며 라우터 액션을 Feature에 전달한다.
@Reducer
struct ProfileCoordinator {
  typealias State = ProfileFeature.State
  private let legalBaseURL: URL?

  init(legalBaseURL: URL?) {
    self.legalBaseURL = legalBaseURL
  }

  @CasePathable
  enum Action {
    case router(IndexedRouterActionOf<ProfileScreen>)
    case profile(ProfileFeature.Action)
  }

  var body: some ReducerOf<Self> {
    Scope(
      state: \.self,
      action: \.profile
    ) {
      ProfileFeature(legalBaseURL: legalBaseURL)
    }

    Reduce { state, action in
      switch action {
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
        action: .account(childAction)
      )) where id == 1:
        return .send(.profile(.destination(.presented(.account(childAction)))))

      case let .router(.routeAction(
        id: id,
        action: .legalDocument(childAction)
      )) where id == 1:
        return .send(.profile(.destination(.presented(.legalDocument(childAction)))))

      case let .router(.routeAction(
        id: id,
        action: .lockScreen(childAction)
      )) where id == 1:
        return .send(.profile(.destination(.presented(.lockScreen(childAction)))))

      case let .router(.routeAction(
        id: id,
        action: .noticeList(childAction)
      )) where id == 1:
        return .send(.profile(.destination(.presented(.noticeList(childAction)))))

      case let .router(.routeAction(
        id: id,
        action: .notifications(childAction)
      )) where id == 1:
        return .send(.profile(.destination(.presented(.notifications(childAction)))))

      case let .router(.updateRoutes(routes)):
        guard state.destination != nil,
              state.destination?.alert == nil,
              routes.count == 1 else { return .none }
        return .send(.profile(.destination(.dismiss)))

      case .router, .profile:
        return .none
      }
    }
  }
}
