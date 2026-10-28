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
    public init() {}
  }

  public enum Action {}

  public var body: some ReducerOf<Self> {
    EmptyReducer()
  }
}
