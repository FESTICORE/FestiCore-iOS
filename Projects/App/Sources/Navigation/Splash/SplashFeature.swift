//
//  SplashFeature.swift
//  FestiCore
//
//  Created by FestiCore on 10/28/26.
//

import ComposableArchitecture

@Reducer
struct SplashFeature {
  @ObservableState
  struct State: Equatable {
    var hasStarted = false
    var didComplete = false
  }

  @CasePathable
  enum Action: ViewAction {
    case view(View)
    case async(AsyncAction)
    case inner(InnerAction)
    case delegate(DelegateAction)
  }

  enum View {
    case onAppear
  }

  @CasePathable
  enum AsyncAction {
    case waitForAnimation
  }

  @CasePathable
  enum InnerAction {
    case animationFinished
  }

  @CasePathable
  enum DelegateAction {
    case presentHome
  }

  @Dependency(\.continuousClock) private var clock

  var body: some ReducerOf<Self> {
    Reduce { state, action in
      switch action {
      case let .view(viewAction):
        return handleViewAction(state: &state, action: viewAction)

      case let .async(asyncAction):
        return handleAsyncAction(action: asyncAction)

      case let .inner(innerAction):
        return handleInnerAction(state: &state, action: innerAction)

      case .delegate:
        return .none
      }
    }
  }
}

private extension SplashFeature {
  func handleViewAction(state: inout State, action: View) -> Effect<Action> {
    guard !state.hasStarted else { return .none }
    state.hasStarted = true
    return .send(.async(.waitForAnimation))
  }

  func handleAsyncAction(action: AsyncAction) -> Effect<Action> {
    switch action {
    case .waitForAnimation:
      return .run { send in
        try await clock.sleep(for: .seconds(2))
        await send(.inner(.animationFinished))
      }
    }
  }

  func handleInnerAction(state: inout State, action: InnerAction) -> Effect<Action> {
    switch action {
    case .animationFinished:
      guard state.hasStarted, !state.didComplete else { return .none }
      state.didComplete = true
      return .send(.delegate(.presentHome))
    }
  }
}
