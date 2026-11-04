import ComposableArchitecture
import FeatureAssembly
import TCAFlow

extension ProfileFeature.State {
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
      case let .notifications(notifications):
        routes.append(.push(.notifications(notifications)))
      }
    }

    return routes
  }
}
