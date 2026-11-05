//
//  AppCoordinator+InnerAction.swift
//  FestiCore
//

import ComposableArchitecture

extension AppCoordinator {
  func handleInnerAction(
    state: inout State,
    action: InnerAction
  ) -> Effect<Action> {
    switch action {
    case let .firstInstallStatus(hasCompleted):
      return handleFirstInstallStatus(
        state: &state,
        hasCompleted: hasCompleted
      )
    case .completeHomeTransition:
      return handleCompleteHomeTransition(state: &state)
    case .sessionExpired:
      return handleSessionExpired(state: &state)
    case let .sessionRestored(
      generation,
      userID,
      isLoggedIn):
      return handleSessionRestored(
        state: &state,
        generation: generation,
        userID: userID,
        isLoggedIn: isLoggedIn
      )
    case let .profileLoaded(
      generation,
      result):
      return handleProfileLoaded(
        state: &state,
        generation: generation,
        result: result
      )
    case let .profileUpdated(
      generation,
      result):
      return handleProfileUpdated(
        state: &state,
        generation: generation,
        result: result
      )
    case let .loginCommitted(
      result,
      generation,
      committed):
      return handleLoginCommitted(
        state: &state,
        result: result,
        generation: generation,
        committed: committed
      )
    case .staleLoginDiscarded:
      return handleStaleLoginDiscarded(state: &state)
    case let .myAccountFinished(
      generation,
      operation,
      result):
      return handleMyAccountFinished(
        state: &state,
        generation: generation,
        operation: operation,
        result: result
      )
    }
  }
}
