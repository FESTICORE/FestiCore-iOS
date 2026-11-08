//
//  AppearanceSettingsView.swift
//  Profile
//
//  Created by FestiCore on 11/8/26.
//

import ComposableArchitecture
import FestiCoreDesignKit
import SwiftUI

/// Figma S13-J 화면 모드(시스템 설정과 같게·라이트·다크)
@ViewAction(for: AppearanceSettingsFeature.self)
public struct AppearanceSettingsView: View {
  public let store: StoreOf<AppearanceSettingsFeature>

  public init(store: StoreOf<AppearanceSettingsFeature>) {
    self.store = store
  }

  public var body: some View {
    VStack(spacing: .zero) {
      FCTopBar(
        .back,
        title: "화면 모드"
      )
      .onBack { send(.backTapped) }
      ScrollView {
        group
          .padding(FestiCoreSpacing.paddingP16)
      }
      .scrollIndicators(.hidden)
    }
    .frame(
      maxWidth: .infinity,
      maxHeight: .infinity,
      alignment: .top
    )
    .background(FestiCoreSemanticColor.backgroundNormal.color)
  }
}

private extension AppearanceSettingsView {
  var group: some View {
    return VStack(
      alignment: .leading,
      spacing: FestiCoreSpacing.paddingP8
    ) {
      // Figma 그룹 제목: Pretendard Bold 13
      Text("화면 모드")
        .festiCoreFont(.baseFootnoteBold)
        .foregroundStyle(FestiCoreSemanticColor.labelAssistive.color)
        .padding(
          .horizontal,
          FestiCoreSpacing.paddingP4
        )
      VStack(spacing: .zero) {
        ForEach(
          Array(AppearanceMode.allCases.enumerated()),
          id: \.element
        ) { index, mode in
          if index > 0 {
            FestiCoreSemanticColor.lineNormal.color
              .frame(height: Metric.divider)
              .padding(
                .leading,
                FestiCoreSpacing.paddingP16
              )
          }
          FCListRow(mode.title) {
            send(.modeTapped(mode))
          }
          .isSelected(store.mode == mode)
        }
      }
      .background(
        FestiCoreSemanticColor.backgroundElevated.color,
        in: RoundedRectangle(cornerRadius: FestiCoreRadius.r16)
      )
      .clipShape(RoundedRectangle(cornerRadius: FestiCoreRadius.r16))
      Text("시스템 설정과 같게를 고르면 기기의 라이트·다크 설정을 따라 자동으로 바뀌어요.")
        .festiCoreFont(.baseFootnoteRegular)
        .foregroundStyle(FestiCoreSemanticColor.labelAssistive.color)
        .padding(
          .horizontal,
          FestiCoreSpacing.paddingP4
        )
    }
  }

  enum Metric {
    static let divider: CGFloat = 1
  }
}
