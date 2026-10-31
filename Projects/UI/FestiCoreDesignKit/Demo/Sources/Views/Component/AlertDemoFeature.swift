//
//  AlertDemoFeature.swift
//  FestiCoreDesignKitDemo
//
//  Created by FestiCore on 10/31/26.
//

import ComposableArchitecture
import FestiCoreSharedUI
import SwiftUI

/// Feature가 `@Presents`로 확인 다이얼로그를 띄우는 흐름을 Demo에서 확인한다.
@Reducer
struct AlertDemoFeature {
  @ObservableState
  struct State: Equatable {
    @Presents var alert: FCAlertState<FCAlertAction>?
  }

  enum Action {
    case showTapped
    case alert(PresentationAction<FCAlertAction>)
  }

  var body: some ReducerOf<Self> {
    Reduce { state, action in
      switch action {
      case .showTapped:
        state.alert = .alert(
          title: "이 안내를 숨길까요?",
          message: "마이 > 설정에서 다시 켤 수 있어요."
        )
        return .none
      case .alert(.presented):
        state.alert = nil
        return .none
      case .alert:
        return .none
      }
    }
    .ifLet(\.$alert, action: \.alert) {
      FCConfirmAlert()
    }
  }
}

/// 화면 전체 위에 `fcAlert`를 띄운다.
struct AlertDemoPresenter: ViewModifier {
  @Bindable var store: StoreOf<AlertDemoFeature>

  func body(content: Content) -> some View {
    content
      .fcAlert($store.scope(state: \.alert, action: \.alert))
  }
}
