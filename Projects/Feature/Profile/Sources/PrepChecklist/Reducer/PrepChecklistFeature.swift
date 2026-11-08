//
//  PrepChecklistFeature.swift
//  Profile
//
//  Created by FestiCore on 11/9/26.
//

import ComposableArchitecture
import Foundation

/// Figma S15-③ 준비 안내 · 준비물. 팩 상세 준비물(PackDetailFeature)의 읽기·체크·내 항목 추가를 그대로 쓰고 단계 이동만 더한다.
@Reducer
public struct PrepChecklistFeature {
  public init() {}

  @ObservableState
  public struct State: Equatable {
    public var detail: PackDetailFeature.State

    /// - Parameter title: 반입 금지 카드에 붙는 페스티벌 이름
    public init(
      festivalID: String,
      title: String
    ) {
      detail = PackDetailFeature.State(
        festivalID: festivalID,
        title: title
      )
      detail.tab = .checklist
    }
  }

  @CasePathable
  public enum Action: ViewAction, Equatable {
    case view(View)
    case detail(PackDetailFeature.Action)
    case delegate(Delegate)
  }

  // MARK: - ViewAction

  @CasePathable
  public enum View: Equatable {
    case onAppear
    case itemToggled(String)
    case newItemTextChanged(String)
    case addItemTapped
    case doneTapped
    case skipTapped
    case laterTapped
  }

  // MARK: - DelegateAction

  @CasePathable
  public enum Delegate: Equatable {
    /// 준비 안내를 마쳤다. 체크는 누를 때마다 기기에 저장했다.
    case finished
    case later
  }

  public var body: some ReducerOf<Self> {
    Scope(
      state: \.detail,
      action: \.detail
    ) {
      PackDetailFeature()
    }
    Reduce { _, action in
      switch action {
      case .view(let viewAction):
        return handleViewAction(action: viewAction)

      case .detail, .delegate:
        return .none
      }
    }
  }
}

extension PrepChecklistFeature {
  private func handleViewAction(action: View) -> Effect<Action> {
    switch action {
    case .onAppear:
      return .send(.detail(.view(.onAppear)))

    case .itemToggled(let id):
      return .send(.detail(.view(.itemToggled(id))))

    case .newItemTextChanged(let text):
      return .send(.detail(.binding(.set(
        \.newItemText,
        text
      ))))

    case .addItemTapped:
      return .send(.detail(.view(.addItemTapped)))

    case .doneTapped, .skipTapped:
      return .send(.delegate(.finished))

    case .laterTapped:
      return .send(.delegate(.later))
    }
  }
}
