//
//  ProfileView.swift
//  Profile
//
//  Created by FestiCore on 10/30/26.
//

import AuthDomainInterface
import ComposableArchitecture
import FestiCoreDesignKit
import SwiftUI

public struct ProfileView: View {
  @Bindable public var store: StoreOf<ProfileFeature>
  public let profile: AuthProfile?
  public let hasSession: Bool
  public let isLoading: Bool
  public let message: String?
  public let packs: [ProfileReceivedPack]
  public let isBearerNavigationAvailable: Bool
  public let isSearchAvailable: Bool
  public let isPackNavigationAvailable: Bool
  public let isLockScreenAvailable: Bool
  public let isNoticeAvailable: Bool

  public init(
    store: StoreOf<ProfileFeature>,
    profile: AuthProfile?,
    hasSession: Bool,
    isLoading: Bool,
    message: String?,
    packs: [ProfileReceivedPack] = [],
    isBearerNavigationAvailable: Bool = false,
    isSearchAvailable: Bool = false,
    isPackNavigationAvailable: Bool = false,
    isLockScreenAvailable: Bool = false,
    isNoticeAvailable: Bool = false
  ) {
    self.store = store
    self.profile = profile
    self.hasSession = hasSession
    self.isLoading = isLoading
    self.message = message
    self.packs = packs
    self.isBearerNavigationAvailable = isBearerNavigationAvailable
    self.isSearchAvailable = isSearchAvailable
    self.isPackNavigationAvailable = isPackNavigationAvailable
    self.isLockScreenAvailable = isLockScreenAvailable
    self.isNoticeAvailable = isNoticeAvailable
  }

  public var body: some View {
    VStack(spacing: .zero) {
      topBar

      ScrollView {
        VStack(spacing: FestiCoreSpacing.paddingP24) {
          FCBearerPrompt { store.send(.view(.bearerTapped)) }
            .allowsHitTesting(isBearerNavigationAvailable)

          receivedPacks
          settings
          information

          Text("FESTICORE v\(appVersion)")
            .festiCoreFont(.baseCaption1Regular)
            .foregroundStyle(FestiCoreSemanticColor.labelAssistive.color)
            .frame(maxWidth: .infinity)
        }
        .padding(.horizontal, FestiCoreSpacing.paddingP16)
        .padding(.top, FestiCoreSpacing.paddingP8)
        .padding(.bottom, FestiCoreSpacing.paddingP24)
      }
      .scrollIndicators(.hidden)
    }
    .frame(maxWidth: .infinity, maxHeight: .infinity)
    .background(FestiCoreSemanticColor.backgroundNormal.color)
    .sheet(isPresented: Binding(
      get: { store.isAccountPresented },
      set: { if !$0 { store.send(.view(.accountDismissed)) } }
    )) {
      accountSheet
        .presentationDetents([.medium])
    }
  }

  @ViewBuilder
  private var topBar: some View {
    if isSearchAvailable {
      FCTopBar(.large, title: "마이")
        .trailingAction { store.send(.view(.searchTapped)) }
    } else {
      FCTopBar(.large, title: "마이")
    }
  }

  private var receivedPacks: some View {
    VStack(spacing: FestiCoreSpacing.paddingP8) {
      HStack {
        sectionTitle("내가 받은 팩")
        Spacer()
        sectionTitle("\(packs.count)개")
      }
      .padding(.horizontal, FestiCoreSpacing.paddingP4)

      VStack(spacing: .zero) {
        if packs.isEmpty {
          Text("받은 팩이 없습니다")
            .festiCoreFont(.baseBodyRegular)
            .foregroundStyle(FestiCoreSemanticColor.labelNeutral.color)
            .frame(maxWidth: .infinity, minHeight: 68)
        } else {
          ForEach(packs) { pack in
            if pack.id != packs.first?.id { rowDivider }
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

  private func packRow(_ pack: ProfileReceivedPack) -> some View {
    let image: Image? = pack.imageName.map { Image($0) }
    return FCPackRow(name: pack.name, meta: pack.detail) {
      store.send(.view(.packTapped(pack.id)))
    }
    .image(image)
    .hasUpdate(pack.hasUpdate)
    .allowsHitTesting(isPackNavigationAvailable)
  }

  private var settings: some View {
    section("설정") {
      FCListRow("알림") { store.send(.view(.notificationsTapped)) }
      rowDivider
      FCListRow("잠금화면") { store.send(.view(.lockScreenTapped)) }
        .allowsHitTesting(isLockScreenAvailable)
      rowDivider
      FCListRow("계정") {
        store.send(.view(.accountTapped(isSignedIn: profile != nil || hasSession)))
      }
      .value(profile?.user.nickname ?? (hasSession ? nil : "로그인"))
    }
  }

  private var information: some View {
    section("정보") {
      FCListRow("공지사항") { store.send(.view(.noticeTapped)) }
        .allowsHitTesting(isNoticeAvailable)
      rowDivider
      FCListRow("이용약관") { store.send(.view(.termsTapped)) }
      rowDivider
      FCListRow("개인정보 처리방침") { store.send(.view(.privacyTapped)) }
    }
  }

  private var accountSheet: some View {
    VStack(alignment: .leading, spacing: FestiCoreSpacing.paddingP16) {
      Text("계정")
        .festiCoreFont(.baseTitle2Bold)

      if let profile {
        Text(profile.user.nickname ?? profile.user.email ?? "내 계정")
          .festiCoreFont(.baseBodyBold)
        if let email = profile.user.email {
          Text(email)
            .festiCoreFont(.baseSubheadlineRegular)
            .foregroundStyle(FestiCoreSemanticColor.labelNeutral.color)
        }
      } else if isLoading {
        ProgressView("계정 정보를 확인하는 중입니다")
      } else {
        Text(message ?? "계정 정보를 확인할 수 없습니다")
          .festiCoreFont(.baseSubheadlineRegular)
        Button("계정 정보 다시 확인") { store.send(.view(.refreshTapped)) }
      }

      Spacer(minLength: .zero)

      Button("로그아웃") {
        store.send(.view(.logoutTapped))
      }
      .disabled(isLoading)
      Button("회원 탈퇴", role: .destructive) {
        store.send(.view(.withdrawTapped))
      }
      .disabled(isLoading)
    }
    .frame(maxWidth: .infinity, alignment: .leading)
    .foregroundStyle(FestiCoreSemanticColor.labelNormal.color)
    .padding(FestiCoreSpacing.paddingP24)
    .background(FestiCoreSemanticColor.backgroundNormal.color)
    .confirmationDialog("로그아웃", isPresented: Binding(
      get: { store.isLogoutConfirmationPresented },
      set: { if !$0 { store.send(.view(.logoutConfirmationDismissed)) } }
    )) {
      Button("로그아웃", role: .destructive) {
        store.send(.view(.confirmLogoutTapped))
      }
    } message: {
      Text("이 기기에서 로그아웃하시겠습니까?")
    }
    .alert("회원 탈퇴", isPresented: Binding(
      get: { store.isWithdrawalConfirmationPresented },
      set: { if !$0 { store.send(.view(.withdrawalConfirmationDismissed)) } }
    )) {
      Button("탈퇴", role: .destructive) {
        store.send(.view(.confirmWithdrawTapped))
      }
      Button("취소", role: .cancel) {}
    } message: {
      Text("계정과 로그인 정보가 삭제됩니다. 이 작업은 되돌릴 수 없습니다.")
    }
  }

  private func sectionTitle(_ title: String) -> some View {
    Text(title)
      .festiCoreFont(.baseCaption1Medium)
      .foregroundStyle(FestiCoreSemanticColor.labelAssistive.color)
  }

  private func section<Content: View>(
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

  private var rowDivider: some View {
    FestiCoreSemanticColor.lineNormal.color
      .frame(height: 1)
      .padding(.leading, FestiCoreSpacing.paddingP16)
  }

  private var appVersion: String {
    Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "1.0.0"
  }
}
