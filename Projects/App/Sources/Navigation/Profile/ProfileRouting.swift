import ComposableArchitecture
import FeatureAssembly
import TCAFlow

extension ProfileFeature.State {
  var hidesTabBarForProfileRoute: Bool {
    guard let screen = profileRoutes.last?.screen else { return false }
    switch screen {
    case .account, .appearance, .legalDocument, .lockScreen, .noticeList, .noticeDetail, .notifications, .packDetail:
      return true
    // Figma S13-0: 설정 홈은 마이 탭이 선택된 탭바를 그대로 보인다. 그 아래 하위 화면은 탭바를 숨긴다.
    case .profile, .bearer, .settings:
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

extension ProfileCoordinator.State {
  /// 마이 경로 위에 기수 설정 흐름을 이어 push한 화면 경로
  var routes: [Route<ProfileScreen.State>] {
    let bearerRoutes = bearer?.pushedRoutes { ProfileScreen.State.bearer($0) } ?? []
    return root.profileRoutes + bearerRoutes
  }

  /// 기수 설정 화면도 다른 마이 하위 화면처럼 탭바 없이 표시한다.
  var hidesTabBarForRoute: Bool {
    return bearer != nil || root.hidesTabBarForProfileRoute
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
