//
//  AppCoordinator+State.swift
//  FestiCore
//

import FestivalDomainInterface
import FeatureAssembly

extension AppCoordinator.State {
  var animationID: String {
    switch self {
    case .splash: "splash"
    case .onboarding: "onboarding"
    case .home: "home"
    }
  }

  var authInputs: MainTabCoordinator.AuthInputs? {
    guard case let .home(home) = self else { return nil }
    return home.authInputs
  }

  /// 개인 일정은 앱 세션과 축제 화면 세션이 모두 활성 상태일 때만 Widget에 담는다.
  var activeWidgetSnapshotContent: FestivalWidgetSnapshot? {
    guard case let .home(home) = self,
          let screen = home.tabs.festival.routes.last(where: {
            $0.screen.is(\.festivalList) || $0.screen.is(\.liveBoard)
          })?.screen else { return nil }
    switch screen {
    case let .festivalList(festival), let .liveBoard(festival):
      return widgetSnapshot(
        from: festival,
        isSessionActive: home.authFlow.hasSession
      )
    default:
      return nil
    }
  }

  private func widgetSnapshot(
    from festival: FestivalFeature.State,
    isSessionActive: Bool
  ) -> FestivalWidgetSnapshot? {
    var festival = festival
    festival.hasSession = isSessionActive && festival.hasSession
    return festival.widgetSnapshotContent
  }
}
