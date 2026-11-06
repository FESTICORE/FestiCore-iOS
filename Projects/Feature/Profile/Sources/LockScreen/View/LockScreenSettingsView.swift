//
//  LockScreenSettingsView.swift
//  Profile
//

import ComposableArchitecture
import FestiCoreDesignKit
import SwiftUI

@ViewAction(for: LockScreenSettingsFeature.self)
public struct LockScreenSettingsView: View {
  public let store: StoreOf<LockScreenSettingsFeature>

  public init(store: StoreOf<LockScreenSettingsFeature>) {
    self.store = store
  }

  public var body: some View {
    VStack(spacing: .zero) {
      FCTopBar(.back, title: "잠금화면")
        .onBack { send(.backTapped) }

      ScrollView {
        VStack(alignment: .leading, spacing: FestiCoreSpacing.paddingP24) {
          Text("공연 전과 진행 중에는 잠금화면에 축제 진행 상황이 자동으로 표시돼요.")
            .festiCoreFont(.baseBodyRegular)
            .foregroundStyle(FestiCoreSemanticColor.labelNeutral.color)
          FCButton("시스템 설정 열기") { send(.openSystemSettingsTapped) }
            .style(.secondary)
            .size(.medium)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(FestiCoreSpacing.paddingP20)
      }
    }
    .frame(maxWidth: .infinity, maxHeight: .infinity)
    .background(FestiCoreSemanticColor.backgroundNormal.color)
  }
}
