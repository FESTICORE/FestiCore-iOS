import ComposableArchitecture
import FeatureAssembly
import TCAFlow

extension ProfileFeature.State {
  var hidesTabBarForProfileRoute: Bool {
    guard let screen = profileRoutes.last?.screen else { return false }
    switch screen {
    case .account, .appearance, .legalDocument, .lockScreen, .noticeList, .noticeDetail, .notifications, .packDetail, .settings:
      return true
    case .profile:
      return false
    }
  }

  /// ProfileFeature의 목적지 하나를 push 경로로 보여 준다. 설정 홈 아래 화면은 그 위에 이어 push한다.
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
      case let .settings(settings):
        routes.append(.push(.settings(settings)))
        routes.append(contentsOf: settings.settingsRoutes)
      }
    }

    return routes
  }
}

extension SettingsHomeFeature.State {
  /// 설정 홈의 하위 목적지(계정·화면 모드·잠금화면·알림·공지·약관)를 push 경로로 보여 준다.
  var settingsRoutes: [Route<ProfileScreen.State>] {
    guard let destination else { return [] }
    switch destination {
    case .alert:
      return []
    case let .account(account):
      return [.push(.account(account))]
    case let .appearance(appearance):
      return [.push(.appearance(appearance))]
    case let .legalDocument(web):
      return [.push(.legalDocument(web))]
    case let .lockScreen(lockScreen):
      return [.push(.lockScreen(lockScreen))]
    case let .noticeList(noticeList):
      guard let detail = noticeList.destination?.detail else { return [.push(.noticeList(noticeList))] }
      return [
        .push(.noticeList(noticeList)),
        .push(.noticeDetail(detail)),
      ]
    case let .notifications(notifications):
      return [.push(.notifications(notifications))]
    }
  }
}
