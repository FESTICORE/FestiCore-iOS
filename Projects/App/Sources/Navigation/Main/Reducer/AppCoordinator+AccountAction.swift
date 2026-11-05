//
//  AppCoordinator+AccountAction.swift
//  FestiCore
//

import ComposableArchitecture
import FestiCoreAnalyticsInterface

extension AppCoordinator {
  func handleMyAccountFinished(
    state: inout State,
    generation: Int,
    operation: MyAccountOperation,
    result: Result<Void, ProfileFailure>
  ) -> Effect<Action> {
    guard case var .home(home) = state,
          home.authFlow.accountOperationGeneration == generation else { return .none }
    home.authFlow.accountOperationGeneration = nil
    home.authFlow.accountOperation = nil
    home.authFlow.isLoading = false
    switch result {
    case .success:
      resetAccountFlow(
        &home.authFlow,
        generation: generation)
      let clear = clearAccountData(&home)
      state = .home(home)
      return clear

    case .failure(.unauthenticated):
      resetAccountFlow(
        &home.authFlow,
        generation: generation
      )
      if operation == .withdraw {
        home.authFlow.message = "로그인이 만료되어 회원 탈퇴 결과를 확인할 수 없어요. 다시 로그인해 계정 상태를 확인해 주세요."
      }
      let clear = clearAccountData(&home)
      state = .home(home)
      return clear

    case .failure:
      home.authFlow.message = operation == .withdraw
        ? "회원 탈퇴에 실패했습니다. 다시 시도해 주세요."
        : "로그아웃에 실패했습니다. 다시 시도해 주세요."
      state = .home(home)
      return .none
    }
  }

  private func resetAccountFlow(
    _ flow: inout AuthFlow,
    generation: Int
  ) {
    analyticsUseCase.reset()
    let latestGeneration = max(
      flow.generation,
      generation)
    flow = AuthFlow()
    flow.generation = latestGeneration
  }
}
