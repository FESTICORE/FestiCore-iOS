//
//  AppearanceSettingsFeature.swift
//  Profile
//
//  Created by FestiCore on 11/8/26.
//

import ComposableArchitecture
import Foundation

import FestiCoreStorageInterface

/// Figma S13-J 화면 모드. 고르면 바로 저장하고 앱 전체에 적용한다.
@Reducer
public struct AppearanceSettingsFeature {
  public init() {}

  @ObservableState
  public struct State: Equatable {
    /// 영속 저장소의 화면 모드 원시 값
    @Shared(.appearanceMode) public var storedMode

    public var mode: AppearanceMode {
      return AppearanceMode(storedValue: storedMode)
    }

    public init() {}
  }

  @CasePathable
  public enum Action: ViewAction, Equatable {
    case view(View)
    case delegate(DelegateAction)
  }

  // MARK: - ViewAction

  @CasePathable
  public enum View: Equatable {
    case modeTapped(AppearanceMode)
    case backTapped
  }

  // MARK: - DelegateAction

  @CasePathable
  public enum DelegateAction: Equatable {
    case backRequested
  }

  public var body: some ReducerOf<Self> {
    Reduce { state, action in
      switch action {
      case .view(let viewAction):
        return handleViewAction(
          state: &state,
          action: viewAction
        )

      case .delegate:
        return .none
      }
    }
  }
}

extension AppearanceSettingsFeature {
  private func handleViewAction(
    state: inout State,
    action: View
  ) -> Effect<Action> {
    switch action {
    case .modeTapped(let mode):
      state.$storedMode.withLock { $0 = mode.rawValue }
      return .none

    case .backTapped:
      return .send(.delegate(.backRequested))
    }
  }
}
