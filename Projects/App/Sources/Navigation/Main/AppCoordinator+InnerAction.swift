//
//  AppCoordinator+InnerAction.swift
//  FestiCore
//
//  Created by FestiCore on 10/23/26.
//

import AuthDomainInterface
import ComposableArchitecture
import FeatureAssembly
import Foundation

extension AppCoordinator {
  func handleInnerAction(
    state: inout State,
    action: InnerAction
  ) -> Effect<Action> {
    switch action {
    case let .firstInstallStatus(hasCompleted):
      guard case .splash = state else { return .none }
      if hasCompleted { return .send(.inner(.completeHomeTransition)) }
      state = .onboarding(.init())
      return .none

    case .completeHomeTransition:
      if case .home = state { return .none }
      state = .home(.init())
      return .merge(
        .send(.view(.foregrounded)),
        .send(.view(.deeplinkReceived)),
        .run { send in
          for await _ in authSessionExpiryClient.events() {
            await send(.scope(.home(.session(.view(.sessionExpired)))))
          }
        }
        .cancellable(
          id: CancelID.sessionExpiry,
          cancelInFlight: true
        )
      )
    }
  }
}
