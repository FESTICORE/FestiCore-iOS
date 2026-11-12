import ComposableArchitecture
import FeatureAssembly
import SwiftUI
import TCAFlow

extension BearerEntryStep {
  /// 마이·가입 스택의 라우터가 push한 기수 화면 하나를 그린다. 화면 액션은 각 화면 View가 보낸다.
  @MainActor
  @ViewBuilder
  static func screen(_ store: StoreOf<BearerEntryStep>) -> some View {
    switch store.case {
    case let .roleChoice(roleStore):
      BearerRoleChoiceView(store: roleStore)
        .toolbar(
          .hidden,
          for: .navigationBar
        )
    case let .register(registerStore):
      BearerRegisterView(store: registerStore)
        .toolbar(
          .hidden,
          for: .navigationBar
        )
    case let .claim(claimStore):
      BearerClaimView(store: claimStore)
        .toolbar(
          .hidden,
          for: .navigationBar
        )
    case let .profile(profileStore):
      BearerProfileView(store: profileStore)
        .swipeBackButtonHidden()
        .toolbar(
          .hidden,
          for: .navigationBar
        )
    case let .planPick(planStore):
      BearerPlanPickView(store: planStore)
        .swipeBackButtonHidden()
        .toolbar(
          .hidden,
          for: .navigationBar
        )
    case let .board(boardStore):
      BearerBoardView(store: boardStore)
        .swipeBackButtonHidden()
        .toolbar(
          .hidden,
          for: .navigationBar
        )
    }
  }
}
