import ComposableArchitecture
import FeatureAssembly
import TCAFlow

extension ProfileFeature.State {
  var hidesTabBarForProfileRoute: Bool {
    guard let screen = profileRoutes.last?.screen else { return false }
    switch screen {
    case .legalDocument, .lockScreen, .noticeList, .noticeDetail, .notifications, .packDetail, .account:
      return true
    case .profile:
      return false
    }
  }

  /// ProfileFeature의 목적지 하나를 push 경로로 보여 준다.
  var profileRoutes: [Route<ProfileScreen.State>] {
    var routes: [Route<ProfileScreen.State>] = [
      .root(
        .profile(self),
        embedInNavigationView: true
      )
    ]

    if let destination {
      switch destination {
      case .alert:
        break
      case let .packDetail(detail):
        routes.append(.push(.packDetail(detail)))
      case let .account(account):
        routes.append(.push(.account(account)))
      case let .legalDocument(web):
        routes.append(.push(.legalDocument(web)))
      case let .lockScreen(lockScreen):
        routes.append(.push(.lockScreen(lockScreen)))
      case let .noticeList(noticeList):
        routes.append(.push(.noticeList(noticeList)))
        if let detail = noticeList.destination?.detail {
          routes.append(.push(.noticeDetail(detail)))
        }
      case let .notifications(notifications):
        routes.append(.push(.notifications(notifications)))
      }
    }

    return routes
  }
}
