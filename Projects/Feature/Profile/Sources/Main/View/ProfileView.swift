//
//  ProfileView.swift
//  Profile
//
//  Created by FestiCore on 10/30/26.
//

import AuthDomainInterface
import ComposableArchitecture
import FestiCoreDesignKit
import FestiCoreSharedUI
import SwiftUI

@ViewAction(for: ProfileFeature.self)
public struct ProfileView: View {
  @Bindable public var store: StoreOf<ProfileFeature>

  public init(store: StoreOf<ProfileFeature>) {
    self.store = store
  }

  public var body: some View {
    VStack(spacing: .zero) {
      topBar

      if !store.hasSession, let message = store.message, !message.isEmpty {
        Text(message)
          .festiCoreFont(.baseSubheadlineRegular)
          .foregroundStyle(FestiCoreSemanticColor.statusNegative.color)
          .frame(maxWidth: .infinity, alignment: .leading)
          .padding(.horizontal, FestiCoreSpacing.paddingP20)
          .accessibilityAddTraits(.updatesFrequently)
      }

      ScrollView {
        VStack(spacing: FestiCoreSpacing.paddingP24) {
          FCBearerPrompt { send(.bearerTapped) }
            .allowsHitTesting(store.isBearerNavigationAvailable)

          receivedPacks
          settings
          information

          if let appVersion {
            Text("FESTICORE v\(appVersion)")
              .festiCoreFont(.baseCaption1Regular)
              .foregroundStyle(FestiCoreSemanticColor.labelAssistive.color)
              .frame(maxWidth: .infinity)
          }
        }
        .padding(.horizontal, FestiCoreSpacing.paddingP16)
        .padding(.top, FestiCoreSpacing.paddingP8)
        .padding(.bottom, FestiCoreSpacing.paddingP24)
      }
      .scrollIndicators(.hidden)
    }
    .frame(maxWidth: .infinity, maxHeight: .infinity)
    .background(FestiCoreSemanticColor.backgroundNormal.color)
  }
}

// MARK: - 상위 화면이 함께 그리는 오버레이

public extension ProfileView {
  /// 탭 화면 전체 위에 올려 탭바 영역까지 시트가 덮도록 한다.
  var modalOverlay: some View {
    Color.clear
      .presentFCSheet(item: accountItem) { _ in
        ProfileAccountSheet(
          profile: store.profile,
          isLoading: store.isLoading,
          message: store.message,
          onRefresh: { send(.refreshTapped) },
          onLogout: { send(.logoutTapped) },
          onWithdraw: { send(.withdrawTapped) }
        )
      }
  }

}

private extension ProfileView {
  @ViewBuilder
  var topBar: some View {
    if store.isSearchAvailable {
      FCTopBar(.large, title: "마이")
        .trailingAction { send(.searchTapped) }
    } else {
      FCTopBar(.large, title: "마이")
    }
  }

  var receivedPacks: some View {
    VStack(spacing: FestiCoreSpacing.paddingP8) {
      HStack {
        sectionTitle("내가 받은 팩")
        Spacer()
        sectionTitle("\(store.packs.count)개")
      }
      .padding(.horizontal, FestiCoreSpacing.paddingP4)

      VStack(spacing: .zero) {
        if store.packs.isEmpty {
          Text("받은 팩이 없습니다")
            .festiCoreFont(.baseBodyRegular)
            .foregroundStyle(FestiCoreSemanticColor.labelNeutral.color)
            .frame(maxWidth: .infinity, minHeight: 68)
        } else {
          ForEach(store.packs) { pack in
            if pack.id != store.packs.first?.id {
              rowDivider
            }
            packRow(pack)
          }
        }
      }
      .background {
        RoundedRectangle(cornerRadius: FestiCoreRadius.r16)
          .fill(FestiCoreSemanticColor.backgroundElevated.color)
      }
    }
  }

  func packRow(_ pack: ProfileReceivedPack) -> some View {
    let image: Image? = pack.imageName.map { Image($0) }
    return FCPackRow(name: pack.name, meta: pack.detail) {
      send(.packTapped(pack.id))
    }
    .image(image)
    .hasUpdate(pack.hasUpdate)
    .allowsHitTesting(store.isPackNavigationAvailable)
  }

  var settings: some View {
    section("설정") {
      FCListRow("알림") { send(.notificationsTapped) }
      rowDivider
      FCListRow("잠금화면") { send(.lockScreenTapped) }
        .allowsHitTesting(store.isLockScreenAvailable)
      rowDivider
      FCListRow("계정") {
        send(.accountTapped)
      }
      .value(store.profile?.user.nickname ?? (store.hasSession ? nil : "로그인"))
    }
  }

  var information: some View {
    section("정보") {
      FCListRow("공지사항") { send(.noticeTapped) }
        .allowsHitTesting(store.isNoticeAvailable)
      rowDivider
      FCListRow("이용약관") { send(.termsTapped) }
      rowDivider
      FCListRow("개인정보 처리방침") { send(.privacyTapped) }
    }
  }

  enum AccountSheet: String, Identifiable {
    case account

    var id: String {
      rawValue
    }
  }

  var accountItem: Binding<AccountSheet?> {
    Binding(
      get: { store.isAccountPresented ? .account : nil },
      set: {
        if $0 == nil {
          send(.accountDismissed)
        }
      }
    )
  }

  func sectionTitle(_ title: String) -> some View {
    Text(title)
      .festiCoreFont(.baseCaption1Medium)
      .foregroundStyle(FestiCoreSemanticColor.labelAssistive.color)
  }

  func section<Content: View>(
    _ title: String,
    @ViewBuilder content: () -> Content
  ) -> some View {
    VStack(alignment: .leading, spacing: FestiCoreSpacing.paddingP8) {
      sectionTitle(title)
        .padding(.horizontal, FestiCoreSpacing.paddingP4)
      VStack(spacing: .zero, content: content)
        .background {
          RoundedRectangle(cornerRadius: FestiCoreRadius.r16)
            .fill(FestiCoreSemanticColor.backgroundElevated.color)
        }
        .clipShape(RoundedRectangle(cornerRadius: FestiCoreRadius.r16))
    }
  }

  var rowDivider: some View {
    FestiCoreSemanticColor.lineNormal.color
      .frame(height: 1)
      .padding(.leading, FestiCoreSpacing.paddingP16)
  }

  var appVersion: String? {
    Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String
  }
}
