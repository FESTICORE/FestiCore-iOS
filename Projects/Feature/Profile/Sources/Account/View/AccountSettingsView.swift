//
//  AccountSettingsView.swift
//  Profile
//
//  Created by FestiCore on 11/3/26.
//

import AuthDomainInterface
import ComposableArchitecture
import FestiCoreDesignKit
import FestiCoreSharedUI
import SwiftUI

/// Figma S13 D 계정
@ViewAction(for: AccountSettingsFeature.self)
public struct AccountSettingsView: View {
  @Bindable public var store: StoreOf<AccountSettingsFeature>

  public init(store: StoreOf<AccountSettingsFeature>) {
    self.store = store
  }

  public var body: some View {
    VStack(spacing: .zero) {
      FCTopBar(.back, title: "계정")
        .onBack { send(.backTapped) }
      ScrollView {
        VStack(alignment: .leading, spacing: FestiCoreSpacing.paddingP24) {
          myInfo()
          withdrawal()
          if let message = store.message, !message.isEmpty, !store.isLoading {
            Text(message)
              .festiCoreFont(.baseSubheadlineRegular)
              .foregroundStyle(FestiCoreSemanticColor.statusNegative.color)
              .accessibilityAddTraits(.updatesFrequently)
          }
        }
        .padding(.horizontal, FestiCoreSpacing.paddingP16)
        // Figma S13-D Contents 위 여백
        .padding(
          .top,
          FestiCoreSpacing.paddingP16
        )
      }
      .scrollIndicators(.hidden)
      .fcScrollBottomInset()
      logoutButton
    }
    .frame(maxWidth: .infinity, maxHeight: .infinity)
    .background(FestiCoreSemanticColor.backgroundNormal.color)
    .toolbar(.hidden, for: .navigationBar)
    .fcModal($store.scope(state: \.destination?.nickname, action: \.destination.nickname)) { nicknameStore in
      NicknameEditView(store: nicknameStore)
    }
    .overlay {
      // 확인 팝업은 별도 층에 띄워 뒤 화면 배치에 애니메이션이 번지지 않게 한다.
      // Figma S13-E: 확인 팝업 제목·설명은 가운데 정렬
      Color.clear
        .fcAlert(
          $store.scope(
            state: \.destination?.alert,
            action: \.destination.alert
          ),
          dismissesOnDimTap: true,
          textAlignment: .center
        )
    }
  }
}

private extension AccountSettingsView {
  @ViewBuilder
  func myInfo() -> some View {
    VStack(alignment: .leading, spacing: FestiCoreSpacing.paddingP8) {
      sectionTitle("내 정보")
      if let user = store.profile?.user {
        VStack(spacing: .zero) {
          FCListRow("닉네임") { send(.nicknameTapped) }
            .value(user.nickname ?? "설정 안 됨")
          divider
          infoRow(
            "로그인",
            value: providerName(user.provider)
          )
        }
        .background(
          FestiCoreSemanticColor.backgroundElevated.color,
          in: RoundedRectangle(cornerRadius: FestiCoreRadius.r16)
        )
        .clipShape(RoundedRectangle(cornerRadius: FestiCoreRadius.r16))
      } else if store.isLoading {
        FCSkeletonView(.round(cornerRadius: FestiCoreRadius.r16))
          .frame(height: 113)
      } else {
        VStack(alignment: .leading, spacing: FestiCoreSpacing.paddingP8) {
          Text("계정 정보를 확인할 수 없습니다")
            .festiCoreFont(.baseSubheadlineRegular)
            .foregroundStyle(FestiCoreSemanticColor.labelNeutral.color)
          FCButton("계정 정보 다시 확인") { send(.refreshTapped) }
            .style(.secondary)
            .size(.medium)
        }
      }
    }
  }

  @ViewBuilder
  func withdrawal() -> some View {
    VStack(alignment: .leading, spacing: FestiCoreSpacing.paddingP8) {
      Button { send(.withdrawTapped) } label: {
        Text("계정 삭제")
          .festiCoreFont(.baseBodyRegular)
          .foregroundStyle(FestiCoreSemanticColor.statusNegative.color)
          .frame(maxWidth: .infinity, minHeight: 56, alignment: .leading)
          .padding(.horizontal, FestiCoreSpacing.paddingP16)
          .background(
            FestiCoreSemanticColor.backgroundElevated.color,
            in: RoundedRectangle(cornerRadius: FestiCoreRadius.r16)
          )
      }
      .buttonStyle(.plain)
      .disabled(store.isLoading)
      Text("계정을 삭제하면 내 일정, 크루, 깃발 기록이 모두 지워지고 되돌릴 수 없어요.")
        .festiCoreFont(.baseFootnoteRegular)
        .festiCoreLineBox(.baseFootnoteRegular)
        .foregroundStyle(FestiCoreSemanticColor.labelAssistive.color)
        .fixedSize(horizontal: false, vertical: true)
        .padding(.horizontal, FestiCoreSpacing.paddingP4)
    }
  }

  /// Figma S13-D Logout: Button ghost·M(85×40)
  var logoutButton: some View {
    return FCButton("로그아웃") { send(.logoutTapped) }
      .style(.ghost)
      .size(.medium)
      .isEnabled(!store.isLoading)
      .frame(maxWidth: .infinity)
      .padding(
        .horizontal,
        FestiCoreSpacing.paddingP16
      )
      .padding(
        .bottom,
        FestiCoreSpacing.paddingP16
      )
  }

  @ViewBuilder
  func infoRow(
    _ title: String,
    value: String
  ) -> some View {
    HStack {
      Text(title)
        .festiCoreFont(.baseBodyRegular)
        .foregroundStyle(FestiCoreSemanticColor.labelNormal.color)
      Spacer()
      Text(value)
        .festiCoreFont(.baseBodyRegular)
        .foregroundStyle(FestiCoreSemanticColor.labelNeutral.color)
    }
    .padding(.horizontal, FestiCoreSpacing.paddingP16)
    .frame(minHeight: 56)
    .accessibilityElement(children: .combine)
  }

  func sectionTitle(_ title: String) -> some View {
    // Figma 그룹 제목: Pretendard Bold 13, 줄 높이 18
    return Text(title)
      .festiCoreFont(.baseFootnoteBold)
      .festiCoreLineBox(.baseFootnoteBold)
      .foregroundStyle(FestiCoreSemanticColor.labelAssistive.color)
      .padding(.horizontal, FestiCoreSpacing.paddingP4)
  }

  var divider: some View {
    FestiCoreSemanticColor.lineNormal.color
      .frame(height: 1)
      .padding(.leading, FestiCoreSpacing.paddingP16)
  }

  func providerName(_ provider: String) -> String {
    return switch provider.lowercased() {
    case "apple": "Apple"
    case "google": "Google"
    default: provider
    }
  }
}

#Preview {
  AccountSettingsView(store: Store(initialState: AccountSettingsFeature.State(profile: nil)) {
    AccountSettingsFeature()
  })
}
