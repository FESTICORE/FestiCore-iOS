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
            await send(.scope(.home(.session(.async(.sessionExpired)))))
          }
        }
        .cancellable(
          id: CancelID.sessionExpiry,
          cancelInFlight: true
        )
      )

    case let .loginCommitted(result, generation, committed):
      return state.withHome { home in
        guard home.authFlow.generation == generation, isActiveLoginAttempt(home.authFlow) else {
          // 확정하는 사이 시트가 닫혔다. 닫은 로그인의 세션은 그 식별자일 때만 되돌린다.
          guard committed, let sessionID = result.sessionID else { return .none }
          return .run { send in
            if await authService.signOut(ifSession: sessionID) {
              await send(.inner(.staleLoginDiscarded))
            }
          }
        }
        home.authFlow.pendingCommitSessionID = nil
        guard committed else {
          // 저장에 실패한 로그인은 시트를 유지해 다시 시도할 수 있게 한다.
          home.authFlow.loginAttemptGeneration = nil
          home.authFlow.isLoading = false
          home.authFlow.message = AuthFlow.Message.loginSaveFailed
          return .none
        }
        return .merge(
          acceptLogin(
            result,
            home: &home
          ),
          .run { _ in await AccountDeviceSync().linkDeviceForCurrentUser() }
        )
      }

    case .staleLoginDiscarded:
      return state.withHome { home in
        // 그 사이 포그라운드 복원이 되돌린 세션을 화면에 반영했다면 저장소 상태를 다시 읽는다.
        guard home.authFlow.hasSession,
              home.authFlow.loginAttemptGeneration == nil,
              home.authFlow.accountOperationGeneration == nil else { return .none }
        return fetchProfile(generation: home.authFlow.beginRequest())
      }

    case let .myAccountFinished(generation, operation, result):
      return state.withHome { home in
        guard home.authFlow.accountOperationGeneration == generation else { return .none }
        home.authFlow.endAccountOperation()
        home.authFlow.isLoading = false
        return handleMyAccountFinished(
          home: &home,
          generation: generation,
          operation: operation,
          result: result
        )
      }
    }
  }
}

// MARK: - 계정 작업

private extension AppCoordinator {
  func handleMyAccountFinished(
    home: inout MainTabCoordinator.State,
    generation: Int,
    operation: MyAccountOperation,
    result: Result<Void, AuthDomainError>
  ) -> Effect<Action> {
    switch result {
    case .success:
      // 계정 분리 — 다음 사용자와 섞이지 않게 분석 식별자와 슈퍼 프로퍼티를 초기화한다.
      analyticsUseCase.reset()
      home.authFlow = clearedAuthFlow(
        after: home.authFlow,
        generation: generation
      )
      return clearAccountData(&home)

    case .failure(.notAuthenticated):
      analyticsUseCase.reset()
      var cleared = clearedAuthFlow(
        after: home.authFlow,
        generation: generation
      )
      if operation == .withdraw {
        cleared.message = AuthFlow.Message.sessionExpiredDuringWithdraw
      }
      home.authFlow = cleared
      return clearAccountData(&home)

    case .failure:
      home.authFlow.message = operation == .withdraw ? AuthFlow.Message.withdrawFailed : AuthFlow.Message.signOutFailed
      return .none
    }
  }

  /// 계정 작업이 끝나면 인증 흐름을 비우되 세대는 되돌리지 않는다.
  func clearedAuthFlow(
    after flow: AuthFlow,
    generation: Int
  ) -> AuthFlow {
    var cleared = AuthFlow()
    cleared.generation = max(
      flow.generation,
      generation
    )
    return cleared
  }
}
