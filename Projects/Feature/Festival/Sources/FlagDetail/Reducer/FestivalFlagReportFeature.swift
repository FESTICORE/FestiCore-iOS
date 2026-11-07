//
//  FestivalFlagReportFeature.swift
//  Festival
//
//  Created by FestiCore on 11/8/26.
//

import ComposableArchitecture
import FestivalDomainInterface

/// Figma S05 E 신고 사유 선택 시트. 사유를 고른 뒤 신고하기를 누르면 부모가 신고를 보낸다.
@Reducer
public struct FestivalFlagReportFeature {
  public init() {}

  @ObservableState
  public struct State: Equatable {
    public var selectedReason: FestivalFlagReportReason?

    public init(selectedReason: FestivalFlagReportReason? = nil) {
      self.selectedReason = selectedReason
    }
  }

  @CasePathable
  public enum Action: ViewAction, Equatable {
    case view(View)
    case delegate(DelegateAction)
  }

  // MARK: - View

  @CasePathable
  public enum View: Equatable {
    case reasonSelected(FestivalFlagReportReason)
    case submitTapped
  }

  // MARK: - Delegate

  @CasePathable
  public enum DelegateAction: Equatable {
    case submitted(FestivalFlagReportReason)
  }

  public var body: some ReducerOf<Self> {
    Reduce { state, action in
      switch action {
      case let .view(viewAction):
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

extension FestivalFlagReportFeature {
  private func handleViewAction(
    state: inout State,
    action: View
  ) -> Effect<Action> {
    switch action {
    case let .reasonSelected(reason):
      state.selectedReason = reason
      return .none

    case .submitTapped:
      // 사유를 고르기 전에는 버튼이 꺼져 있지만 접근성 동작으로 들어와도 보내지 않는다.
      guard let reason = state.selectedReason else { return .none }
      return .send(.delegate(.submitted(reason)))
    }
  }
}
