//
//  BearerZonePickerView.swift
//  Bearer
//
//  Created by FestiCore on 11/3/26.
//

import BearerDomainInterface
import ComposableArchitecture
import FestiCoreDesignKit
import SwiftUI

/// Figma S09 B 존 고르기 시트
@ViewAction(for: BearerZonePickerFeature.self)
public struct BearerZonePickerView: View {
  public let store: StoreOf<BearerZonePickerFeature>

  public init(store: StoreOf<BearerZonePickerFeature>) {
    self.store = store
  }

  public var body: some View {
    VStack(
      alignment: .leading,
      spacing: FestiCoreSpacing.paddingP16
    ) {
      header
      if store.zones.isEmpty {
        Text("받아 둔 페스티벌 정보에 존이 없어요. 라이브 보드에서 정보를 받은 뒤 다시 열어 주세요.")
          .festiCoreFont(.baseFootnoteRegular)
          .foregroundStyle(FestiCoreSemanticColor.labelAssistive.color)
      } else {
        zoneGrid
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

private extension BearerZonePickerView {
  var header: some View {
    return VStack(
      alignment: .leading,
      spacing: FestiCoreSpacing.marginM4
    ) {
      Text("지금 어느 존에 있나요?")
        .festiCoreFont(.baseTitle2Bold)
        .festiCoreLineBox(.baseTitle2Bold)
        .foregroundStyle(FestiCoreSemanticColor.labelStrong.color)
      Text("누르면 장소 정보가 바로 바뀌고 팔로워에게 알림이 가요")
        .festiCoreFont(.baseFootnoteRegular)
        .festiCoreLineBox(.baseFootnoteRegular)
        .foregroundStyle(FestiCoreSemanticColor.labelAssistive.color)
    }
  }

  // 시트는 내용 높이를 따르고, 존이 많으면 최대 높이 안에서 스크롤한다.
  var zoneGrid: some View {
    return ScrollView {
      LazyVGrid(
        columns: [GridItem(.flexible()), GridItem(.flexible())],
        spacing: FestiCoreSpacing.marginM12
      ) {
        ForEach(store.zones) { zone in
          FCChoiceTile(
            zone.name,
            icon: .locationDot16
          ) {
            send(.zoneTapped(zone.id))
          }
          .isSelected(zone.id == store.selectedZoneID)
        }
      }
    }
    .scrollBounceBehavior(.basedOnSize)
    .frame(height: gridHeight)
  }

  var gridHeight: CGFloat {
    let rows = CGFloat((store.zones.count + 1) / 2)
    let gaps = max(
      0,
      rows - 1
    )
    let content = rows * Metric.tileHeight + gaps * FestiCoreSpacing.marginM12
    return min(
      content,
      Metric.maxGridHeight
    )
  }

  enum Metric {
    static let tileHeight: CGFloat = 44
    static let maxGridHeight: CGFloat = 420
  }
}

#Preview {
  BearerZonePickerView(store: .init(initialState: BearerZonePickerFeature.State(
    zones: [],
    selectedZoneID: nil
  )) {
    BearerZonePickerFeature()
  })
}
