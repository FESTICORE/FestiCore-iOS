//
//  SettingsHomeView.swift
//  Profile
//
//  Created by FestiCore on 11/12/26.
//

import ComposableArchitecture
import FestiCoreDesignKit
import FestiCoreSharedUI
import SwiftUI

/// Figma S13-0 설정 홈(앱·계정·정보 그룹과 버전)
@ViewAction(for: SettingsHomeFeature.self)
public struct SettingsHomeView: View {
  @Bindable public var store: StoreOf<SettingsHomeFeature>

  public init(store: StoreOf<SettingsHomeFeature>) {
    self.store = store
  }

  public var body: some View {
    VStack(spacing: .zero) {
      FCTopBar(
        .back,
        title: "설정"
      )
      .onBack { send(.backTapped) }

      ScrollView {
        VStack(spacing: FestiCoreSpacing.paddingP24) {
          appGroup
          if store.showsAccount {
            accountGroup
          }
          informationGroup
          versionText
        }
        .padding(
          .horizontal,
          FestiCoreSpacing.paddingP16
        )
        .padding(
          .top,
          FestiCoreSpacing.paddingP16
        )
      }
      .scrollIndicators(.hidden)
      .fcScrollBottomInset()
    }
    .frame(
      maxWidth: .infinity,
      maxHeight: .infinity,
      alignment: .top
    )
    .background(FestiCoreSemanticColor.backgroundNormal.color)
    .overlay {
      Color.clear
        .fcAlert(
          $store.scope(
            state: \.destination?.alert,
            action: \.destination.alert
          ),
          dismissesOnDimTap: true
        )
    }
  }
}

private extension SettingsHomeView {
  var appGroup: some View {
    return section("앱") {
      FCListRow("알림") { send(.notificationsTapped) }
      rowDivider
      FCListRow("잠금화면") { send(.lockScreenTapped) }
      rowDivider
      FCListRow("화면 모드") { send(.appearanceTapped) }
        .value(store.appearanceMode.summary)
    }
  }

  var accountGroup: some View {
    return section("계정") {
      FCListRow("계정") { send(.accountTapped) }
        .value(store.profile?.user.nickname)
    }
  }

  var informationGroup: some View {
    return section("정보") {
      FCListRow("공지사항") { send(.noticeTapped) }
      rowDivider
      FCListRow("정보 출처") { send(.sourcesTapped) }
      rowDivider
      FCListRow("이용약관") { send(.termsTapped) }
      rowDivider
      FCListRow("개인정보 처리방침") { send(.privacyTapped) }
    }
  }

  @ViewBuilder
  var versionText: some View {
    if let appVersion {
      Text("FESTICORE v\(appVersion)")
        .festiCoreFont(.baseCaption1Regular)
        .foregroundStyle(FestiCoreSemanticColor.labelAssistive.color)
        .frame(maxWidth: .infinity)
    }
  }

  /// Figma S13-0 그룹 제목: Pretendard Bold 13, 줄 높이 18
  func sectionTitle(_ title: String) -> some View {
    return Text(title)
      .festiCoreFont(.baseFootnoteBold)
      .festiCoreLineBox(.baseFootnoteBold)
      .foregroundStyle(FestiCoreSemanticColor.labelAssistive.color)
  }

  func section<Content: View>(
    _ title: String,
    @ViewBuilder content: () -> Content
  ) -> some View {
    return VStack(
      alignment: .leading,
      spacing: FestiCoreSpacing.paddingP8
    ) {
      sectionTitle(title)
        .padding(
          .horizontal,
          FestiCoreSpacing.paddingP4
        )
      VStack(
        spacing: .zero,
        content: content
      )
      .background {
        RoundedRectangle(cornerRadius: FestiCoreRadius.r16)
          .fill(FestiCoreSemanticColor.backgroundElevated.color)
      }
      .clipShape(RoundedRectangle(cornerRadius: FestiCoreRadius.r16))
    }
  }

  var rowDivider: some View {
    return FestiCoreSemanticColor.lineNormal.color
      .frame(height: 1)
      .padding(
        .leading,
        FestiCoreSpacing.paddingP16
      )
  }

  var appVersion: String? {
    return Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String
  }
}

#Preview {
  SettingsHomeView(store: .init(initialState: SettingsHomeFeature.State()) {
    SettingsHomeFeature()
  })
}
