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
    VStack(
      alignment: .leading,
      spacing: FestiCoreSpacing.paddingP16
    ) {
      header
      LazyVGrid(
        columns: [GridItem(.flexible()), GridItem(.flexible())],
        spacing: FestiCoreSpacing.marginM12
      ) {
        ForEach(
          BearerActivity.allCases,
          id: \.self
        ) { activity in
          FCChoiceTile(
            activity.title,
            icon: icon(for: activity)
          ) {
            send(.activityTapped(activity))
          }
          .size(.activity)
          .isSelected(activity == store.selected)
          .frame(height: Metric.tileHeight)
        }
      }
    }
    // 시트가 손잡이 아래 16pt를 두므로 위 여백은 넣지 않는다.
    .padding(
      .horizontal,
      FestiCoreSpacing.paddingP16
    )
    .padding(
      .bottom,
      FestiCoreSpacing.paddingP16
    )
  }
}

private extension BearerActivityPickerView {
  var header: some View {
    return VStack(
      alignment: .leading,
      spacing: FestiCoreSpacing.marginM4
    ) {
      Text("지금 뭐 하고 있나요?")
        .festiCoreFont(.baseTitle2Bold)
        .festiCoreLineBox(.baseTitle2Bold)
        .foregroundStyle(FestiCoreSemanticColor.labelStrong.color)
      Text("누르면 바로 바뀌어요")
        .festiCoreFont(.baseFootnoteRegular)
        .festiCoreLineBox(.baseFootnoteRegular)
        .foregroundStyle(FestiCoreSemanticColor.labelAssistive.color)
    }
  }

  func icon(for activity: BearerActivity) -> ImageAsset {
    switch activity {
    case .slam: return .users24
    case .sing: return .music24
    case .train: return .route24
    case .calm: return .user24
    }
  }

  enum Metric {
    static let tileHeight: CGFloat = 96
  }
}

#Preview {
  BearerActivityPickerView(store: .init(initialState: BearerActivityPickerFeature.State(selected: .slam)) {
    BearerActivityPickerFeature()
  })
}
