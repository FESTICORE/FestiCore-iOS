//
//  NicknameEditView.swift
//  Profile
//
//  Created by FestiCore on 11/3/26.
//

import ComposableArchitecture
import FestiCoreDesignKit
import SwiftUI

/// 닉네임 변경 바텀시트. 가입 화면의 닉네임 입력 컴포넌트를 그대로 쓴다.
@ViewAction(for: NicknameEditFeature.self)
public struct NicknameEditView: View {
  @Bindable public var store: StoreOf<NicknameEditFeature>

  public init(store: StoreOf<NicknameEditFeature>) {
    self.store = store
  }

  public var body: some View {
    VStack(alignment: .leading, spacing: FestiCoreSpacing.paddingP24) {
      Text("닉네임 변경")
        .festiCoreFont(.baseTitle2Bold)
        .foregroundStyle(FestiCoreSemanticColor.labelNormal.color)
        .accessibilityAddTraits(.isHeader)
      FCTextField(
        text: Binding(
          get: { store.nickname },
          set: { send(.nicknameChanged($0)) }
        ),
        placeholder: "닉네임"
      )
      .label("닉네임")
      .maxLength(12)
      .helper("1~12자로 입력해 주세요")
      .error(store.errorMessage)
      FCButton(store.isSaving ? "저장하는 중" : "저장") { send(.saveTapped) }
        .style(.primary)
        .isFullWidth(true)
        .isEnabled(!store.isSaving)
    }
    .padding(.horizontal, FestiCoreSpacing.paddingP20)
    .padding(.bottom, FestiCoreSpacing.paddingP24)
  }
}

#Preview {
  NicknameEditView(store: Store(initialState: NicknameEditFeature.State(nickname: "로이")) {
    NicknameEditFeature()
  })
}
