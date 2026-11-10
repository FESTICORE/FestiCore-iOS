//
//  AppCoordinator+ViewAction.swift
//  FestiCore
//
//  Created by FestiCore on 10/23/26.
//

import ComposableArchitecture
import CoreAssembly
import FestiCoreUtility
import Foundation

extension AppCoordinator {
  func handleViewAction(
    state: inout State,
    action: View
  ) -> Effect<Action> {
    switch action {
    case .presentHome:
      guard case .splash = state else { return .none }
      return .run { send in
        // 이전 실행에서 남은 개인 Widget 파일은 세션 확인 전에 지운다.
        await festivalWidgetClient.save(nil)
        do {
          await send(.inner(.firstInstallStatus(try firstInstallOnboardingStore.hasCompleted())))
        } catch {
          FestiCoreLogger.error(
            "첫 설치 기록을 확인할 수 없음: \(error.localizedDescription)",
            category: .app
          )
          await send(.inner(.firstInstallStatus(true)))
        }
      }

    case .foregrounded:
      guard case .home = state else { return .none }
      return .merge(
        .send(.scope(.home(.festival(.foregrounded)))),
        .send(.scope(.home(.session(.view(.foregrounded)))))
      )

    case .backgrounded:
      guard case .home = state else { return .none }
      return .send(.scope(.home(.festival(.backgrounded))))

    case .remoteContentChanged:
      guard case .home = state else { return .none }
      return .send(.scope(.home(.festival(.remoteContentChanged))))

    case let .openDeeplink(deeplink):
      guard case .home = state else { return .none }
      return .send(.scope(.home(.openDeeplink(deeplink))))

    case .deeplinkReceived:
      // 홈 전환 전이면 대기 값을 남겨 두고, 홈에 들어갈 때 다시 꺼낸다.
      guard case .home = state, let deeplink = AppDeeplinkBridge.consumePending() else { return .none }
      return .send(.view(.openDeeplink(deeplink)))
    }
  }
}
