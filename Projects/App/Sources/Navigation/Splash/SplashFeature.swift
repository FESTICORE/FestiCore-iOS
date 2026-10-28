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
    case timerFinished
    case delegate(Delegate)
  }

  enum View {
    case onAppear
    case onDisappear
  }

  @CasePathable
  enum Delegate {
    case presentHome
  }

  private enum CancelID: Hashable {
    case timer
  }

  @Dependency(\.continuousClock) private var clock

  var body: some ReducerOf<Self> {
    Reduce { state, action in
      switch action {
      case .view(.onAppear):
        guard !state.hasStarted else { return .none }
        state.hasStarted = true
        return .run { send in
          try await clock.sleep(for: .seconds(3))
          await send(.timerFinished)
        }
        .cancellable(id: CancelID.timer)

      case .view(.onDisappear):
        if !state.didComplete {
          state.hasStarted = false
        }
        return .cancel(id: CancelID.timer)

      case .timerFinished:
        guard state.hasStarted, !state.didComplete else { return .none }
        state.didComplete = true
        return .send(.delegate(.presentHome))

      case .delegate:
        return .none
      }
    }
  }
}
