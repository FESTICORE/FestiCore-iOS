//
//  BearerZonePickerView.swift
//  Bearer
//
//  Created by FestiCore on 11/3/26.
//

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
    VStack(alignment: .leading, spacing: FestiCoreSpacing.paddingP16) {
      VStack(alignment: .leading, spacing: FestiCoreSpacing.marginM4) {
        Text("지금 어느 존에 있나요?")
          .festiCoreFont(.baseTitle2Bold)
          .foregroundStyle(FestiCoreSemanticColor.labelStrong.color)
        Text("누르면 장소 정보가 바로 바뀌고 팔로워에게 알림이 가요")
          .festiCoreFont(.baseFootnoteRegular)
          .foregroundStyle(FestiCoreSemanticColor.labelNeutral.color)
      }
      if store.zones.isEmpty {
        Text("받아 둔 페스티벌 정보에 존이 없어요. 라이브 보드에서 정보를 받은 뒤 다시 열어 주세요.")
          .festiCoreFont(.baseFootnoteRegular)
          .foregroundStyle(FestiCoreSemanticColor.labelAssistive.color)
      } else {
        ScrollView {
          LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: FestiCoreSpacing.marginM12) {
            ForEach(store.zones) { zone in
              BearerZoneButton(name: zone.name, isSelected: zone.id == store.selectedZoneID) {
                send(.zoneTapped(zone.id))
              }
            }
          }
        }
        .frame(maxHeight: 420)
      }
    }
    .padding(FestiCoreSpacing.paddingP16)
  }
}

#Preview {
  BearerZonePickerView(store: .init(initialState: BearerZonePickerFeature.State(zones: [], selectedZoneID: nil)) {
    BearerZonePickerFeature()
  })
}
