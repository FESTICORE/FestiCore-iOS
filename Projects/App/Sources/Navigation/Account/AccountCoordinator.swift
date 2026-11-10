//
//  AccountCoordinator.swift
//  FestiCore
//

import AuthDomainInterface
import ComposableArchitecture
import FestiCoreAnalyticsInterface
import FestiCoreAuthInterface
import Foundation

/// 마이 화면의 로그아웃·탈퇴를 맡는다. 기기 해제와 Live Activity 종료 뒤 인증 요청을 보내고, 세대(`generation`)로 늦게 온 결과를 버린다.
@Reducer
struct AccountCoordinator {
  @Dependency(\.authUseCase) var authUseCase
  @Dependency(\.authService) var authService
  @Dependency(\.analyticsUseCase) var analyticsUseCase

  typealias State = SessionCoordinator.State

  enum CancelID { case operation }

  enum Operation: Equatable, Sendable {
    case signOut
    case withdraw
  }

  // MARK: - Action

  enum Action {
    case view(View)
    case inner(InnerAction)
    case delegate(Delegate)
  }

  // MARK: - View

  @CasePathable
  enum View {
    case signOutRequested
    case withdrawRequested
    /// 세션이 끝나 진행 중이던 계정 작업을 취소한다.
    case cancelOperation
  }

  // MARK: - Inner

  @CasePathable
  enum InnerAction {
    case finished(
      generation: Int,
      operation: Operation,
      result: Result<Void, AuthDomainError>
    )
  }

  // MARK: - Delegate

  @CasePathable
  enum Delegate {
    /// 이전 계정의 화면 데이터를 바로 비우고 축제 화면에 알린다.
    case accountDataCleared
    /// 계정 작업 중 인증을 잃었다. 세션 만료 처리를 맡긴다.
    case sessionExpired
  }

  var body: some ReducerOf<Self> {
    Reduce { state, action in
      return handleRoute(
        state: &state,
        action: action
      )
    }
  }

  func handleRoute(
    state: inout State,
    action: Action
  ) -> Effect<Action> {
    switch action {
    case let .view(action):
      return handleViewAction(
        state: &state,
        action: action
      )
    case let .inner(action):
      return handleInnerAction(
        state: &state,
        action: action
      )
    case .delegate:
      return .none
    }
  }
}

extension AccountCoordinator {
  private func handleViewAction(
    state: inout State,
    action: View
  ) -> Effect<Action> {
    switch action {
    case .signOutRequested:
      return startOperation(
        .signOut,
        state: &state
      )
    case .withdrawRequested:
      return startOperation(
        .withdraw,
        state: &state
      )
    case .cancelOperation:
      return .cancel(id: CancelID.operation)
    }
  }

  private func handleInnerAction(
    state: inout State,
    action: InnerAction
  ) -> Effect<Action> {
    switch action {
    case let .finished(generation, operation, result):
      guard state.accountOperationGeneration == generation else { return .none }
      state.endAccountOperation()
      state.isLoading = false
      return handleMyAccountFinished(
        state: &state,
        generation: generation,
        operation: operation,
        result: result
      )
    }
  }
}

// MARK: - 계정 작업

private extension AccountCoordinator {
  func startOperation(
    _ operation: Operation,
    state: inout State
  ) -> Effect<Action> {
    guard state.hasSession, !state.isLoading else { return .none }
    let generation = state.beginRequest()
    state.accountOperationGeneration = generation
    state.accountOperation = operation
    state.message = nil
    return runOperation(
      operation,
      generation: generation
    )
  }

  func runOperation(
    _ operation: Operation,
    generation: Int
  ) -> Effect<Action> {
    return .run { send in
      do {
        let device = AccountDeviceSync()
        await device.unbindDeviceForAccountOperation()
        try Task.checkCancellation()
        await device.endLocalLiveActivities()
        try Task.checkCancellation()
        switch operation {
        case .signOut: try await authUseCase.signOut()
        case .withdraw: try await authUseCase.withdraw()
        }
        await send(.inner(.finished(
          generation: generation,
          operation: operation,
          result: .success(())
        )))
      } catch {
        guard !Task.isCancelled else { return }
        if !(await authService.isLoggedIn) {
          await send(.delegate(.sessionExpired))
          return
        }
        // 인증 요청은 실패했지만 계정이 유지되면 해제했던 기기 소유권을 복원한다.
        await AccountDeviceSync().linkDeviceForCurrentUser()
        await send(.inner(.finished(
          generation: generation,
          operation: operation,
          result: .failure(SessionCoordinator.authFailure(error))
        )))
      }
    }
    .cancellable(
      id: CancelID.operation,
      cancelInFlight: true
    )
  }

  func handleMyAccountFinished(
    state: inout State,
    generation: Int,
    operation: Operation,
    result: Result<Void, AuthDomainError>
  ) -> Effect<Action> {
    switch result {
    case .success:
      // 계정 분리 — 다음 사용자와 섞이지 않게 분석 식별자와 슈퍼 프로퍼티를 초기화한다.
      analyticsUseCase.reset()
      state = clearedAuthFlow(
        after: state,
        generation: generation
      )
      return .send(.delegate(.accountDataCleared))

    case .failure(.notAuthenticated):
      analyticsUseCase.reset()
      var cleared = clearedAuthFlow(
        after: state,
        generation: generation
      )
      if operation == .withdraw {
        cleared.message = State.Message.sessionExpiredDuringWithdraw
      }
      state = cleared
      return .send(.delegate(.accountDataCleared))

    case .failure:
      state.message = operation == .withdraw ? State.Message.withdrawFailed : State.Message.signOutFailed
      return .none
    }
  }

  /// 계정 작업이 끝나면 인증 흐름을 비우되 세대와 로그인 시트 화면 상태는 되돌리지 않는다.
  func clearedAuthFlow(
    after flow: State,
    generation: Int
  ) -> State {
    var cleared = State()
    cleared.generation = max(
      flow.generation,
      generation
    )
    cleared.login = flow.login
    return cleared
  }
}
