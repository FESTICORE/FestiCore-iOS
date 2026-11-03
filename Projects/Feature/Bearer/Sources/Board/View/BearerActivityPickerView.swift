//
//  BearerActivityPickerView.swift
//  Bearer
//
//  Created by FestiCore on 11/3/26.
//

import BearerDomainInterface
import ComposableArchitecture
import FestiCoreDesignKit
import SwiftUI

/// Figma S09 C 활동 고르기 시트
@ViewAction(for: BearerActivityPickerFeature.self)
public struct BearerActivityPickerView: View {
  public let store: StoreOf<BearerActivityPickerFeature>

  public init(store: StoreOf<BearerActivityPickerFeature>) {
    self.store = store
  }

  public var body: some View {
    VStack(alignment: .leading, spacing: FestiCoreSpacing.paddingP16) {
      VStack(alignment: .leading, spacing: FestiCoreSpacing.marginM4) {
        Text("지금 뭐 하고 있나요?")
          .festiCoreFont(.baseTitle2Bold)
          .foregroundStyle(FestiCoreSemanticColor.labelStrong.color)
        Text("누르면 바로 바뀌어요")
          .festiCoreFont(.baseFootnoteRegular)
          .foregroundStyle(FestiCoreSemanticColor.labelNeutral.color)
      }
      LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: FestiCoreSpacing.marginM12) {
        ForEach(BearerActivity.allCases, id: \.self) { activity in
          FCBigButton(activity.title, sub: "", icon: icon(for: activity)) {
            send(.activityTapped(activity))
          }
          .isSelected(activity == store.selected)
          .frame(height: 120)
        }
      }
    }
    .padding(FestiCoreSpacing.paddingP16)
  }
}

extension BearerActivityPickerView {
  private func icon(for activity: BearerActivity) -> ImageAsset {
    switch activity {
    case .slam: return .users24
    case .sing: return .music24
    case .train: return .route24
    case .calm: return .user24
    }
  }
}

#Preview {
  BearerActivityPickerView(store: .init(initialState: BearerActivityPickerFeature.State(selected: .slam)) {
    BearerActivityPickerFeature()
  })
}
