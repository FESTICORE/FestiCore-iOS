//
//  BearerRoleChoiceFeature.swift
//  Bearer
//
//  Created by FestiCore on 11/12/26.
//

import BearerInterface
import ComposableArchitecture
import Foundation

/// Figma S14 C·C2 기수 여부. 관객이면 흐름을 마치고, 기수면 깃발 프로필 등록(D)으로 간다.
@Reducer
public struct BearerRoleChoiceFeature {
  public init() {}

  public enum Role: Equatable, Sendable, CaseIterable {
    case audience
    case bearer
  }

  @ObservableState
  public struct State: Equatable {
    public var role: Role?

    public init(role: Role? = nil) {
      self.role = role
    }
  }

  @CasePathable
  public enum Action: ViewAction, Equatable {
    case view(View)
    case delegate(DelegateAction)
  }

  @CasePathable
  public enum View: Equatable {
    case roleTapped(Role)
    case nextTapped
    case backTapped
  }

  public typealias DelegateAction = BearerRoleChoiceDelegate

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

extension BearerRoleChoiceFeature {
  private func handleViewAction(
    state: inout State,
    action: View
  ) -> Effect<Action> {
    switch action {
    case .roleTapped(let role):
      state.role = role
      return .none

    case .nextTapped:
      switch state.role {
      case .audience: return .send(.delegate(.audienceChosen))
      case .bearer: return .send(.delegate(.bearerChosen))
      case nil: return .none
      }

    case .backTapped:
      return .send(.delegate(.closeRequested))
    }
  }
}
