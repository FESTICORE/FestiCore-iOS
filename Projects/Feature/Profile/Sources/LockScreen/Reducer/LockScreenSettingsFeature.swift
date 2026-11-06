//
//  LockScreenSettingsFeature.swift
//  Profile
//

import ComposableArchitecture
import Foundation
import UIKit

@Reducer
public struct LockScreenSettingsFeature {
  public init() {}

  @ObservableState
  public struct State: Equatable {
    public init() {}
  }

  @CasePathable
  public enum Action: ViewAction, Equatable {
    case view(View)
    case delegate(DelegateAction)
  }

  @CasePathable
  public enum View: Equatable {
    case backTapped
    case openSystemSettingsTapped
  }

  @CasePathable
  public enum DelegateAction: Equatable {
    case backRequested
  }

  @Dependency(\.openURL) private var openURL

  public var body: some ReducerOf<Self> {
    Reduce { _, action in
      switch action {
      case .view(.backTapped):
        return .send(.delegate(.backRequested))

      case .view(.openSystemSettingsTapped):
        guard let url = URL(string: UIApplication.openSettingsURLString) else { return .none }
        return .run { _ in await openURL(url) }

      case .delegate:
        return .none
      }
    }
  }
}
