//
//  BearerActivityPickerFeature.swift
//  Bearer
//
//  Created by FestiCore on 11/3/26.
//

import BearerDomainInterface
import ComposableArchitecture

/// Figma S09 C 활동 고르기 시트
@Reducer
public struct BearerActivityPickerFeature {
  public init() {}

  @ObservableState
  public struct State: Equatable {
    public let selected: BearerActivity?

    public init(selected: BearerActivity?) {
      self.selected = selected
    }
  }

  @CasePathable
  public enum Action: ViewAction, Equatable {
    case view(View)
    case delegate(DelegateAction)
  }

  // MARK: - ViewAction

  @CasePathable
  public enum View: Equatable {
    case activityTapped(BearerActivity)
  }

  // MARK: - DelegateAction

  @CasePathable
  public enum DelegateAction: Equatable {
    case picked(BearerActivity)
  }

  public var body: some ReducerOf<Self> {
    Reduce { _, action in
      switch action {
      case .view(.activityTapped(let activity)):
        return .send(.delegate(.picked(activity)))

      case .delegate:
        return .none
      }
    }
  }
}
