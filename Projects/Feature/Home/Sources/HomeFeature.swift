//
//  HomeFeature.swift
//  Home
//
//  Created by FestiCore on 10/23/26.
//

import ComposableArchitecture

@Reducer
public struct HomeFeature {
  public init() {}

  @ObservableState
  public struct State: Equatable {
    public var configurationIsAvailable: Bool

    public init(configurationIsAvailable: Bool) {
      self.configurationIsAvailable = configurationIsAvailable
    }
  }

  public enum Action {
    case configurationStatusChanged(Bool)
  }

  public var body: some ReducerOf<Self> {
    Reduce { state, action in
      switch action {
      case .configurationStatusChanged(let isAvailable):
        state.configurationIsAvailable = isAvailable
        return .none
      }
    }
  }
}
