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
          analyticsGroup
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

  var analyticsGroup: some View {
    return VStack(
      alignment: .leading,
      spacing: FestiCoreSpacing.paddingP8
    ) {
      section("개인정보 선택") {
        FCListRow(
          "분석 및 진단 정보 공유",
          isOn: Binding(
          get: { store.analyticsCollectionEnabled },
            set: { send(.analyticsCollectionChanged($0)) }
          )
        )
      }
      Text("앱 이용 기록과 오류 정보를 서비스 개선에 사용해요. 선택 사항이며 언제든 끌 수 있어요. 수집 항목과 처리 방법은 개인정보 처리방침에서 확인해 주세요.")
        .festiCoreFont(.baseFootnoteRegular)
        .foregroundStyle(FestiCoreSemanticColor.labelAssistive.color)
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
      rowDivider
      FCListRow("위치기반서비스 이용약관") { send(.locationTermsTapped) }
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
      // Figma S13-0 Divider: 카드 너비를 채운다(361)
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
