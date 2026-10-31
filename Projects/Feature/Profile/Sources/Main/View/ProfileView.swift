//
//  ProfileView.swift
//  Profile
//
//  Created by FestiCore on 10/30/26.
//

import AuthDomainInterface
import ComposableArchitecture
import FestiCoreAnimation
import FestiCoreDesignKit
import FestiCoreSharedUI
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
    .onChange(of: hasSession) { wasSignedIn, isSignedIn in
      if wasSignedIn && !isSignedIn && store.isAccountPresented {
        store.send(.view(.accountDismissed))
      }
    }
  }

  /// 탭 화면 전체 위에 올려 탭바 영역까지 시트가 덮도록 한다.
  public var modalOverlay: some View {
    Color.clear
      .presentFCSheet(item: accountItem) { _ in
        ProfileAccountSheet(
          profile: profile,
          isLoading: isLoading,
          message: message,
          onRefresh: { store.send(.view(.refreshTapped)) },
          onLogout: { store.send(.view(.logoutTapped)) },
          onWithdraw: { store.send(.view(.withdrawTapped)) }
        )
      }
  }

  /// 로그아웃·탈퇴·링크 안내 확인 팝업. 시트 위층에 항상 두어 닫힘 애니메이션이 잘리지 않게 한다.
  public var dialogOverlay: some View {
    ZStack {
      confirmationOverlay
        .id(store.dialogPresentationID)
    }
    .animation(.fcModal, value: store.dialogPresentationID)
    .animation(.fcModal, value: store.isLogoutConfirmationPresented)
    .animation(.fcModal, value: store.isWithdrawalConfirmationPresented)
    .animation(.fcModal, value: store.isLegalLinkUnavailablePresented)
  }
}

private extension ProfileView {
  @ViewBuilder
  var topBar: some View {
    if isSearchAvailable {
      FCTopBar(.large, title: "마이")
        .trailingAction { store.send(.view(.searchTapped)) }
    } else {
      FCTopBar(.large, title: "마이")
    }
  }

  var receivedPacks: some View {
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

  func packRow(_ pack: ProfileReceivedPack) -> some View {
    let image: Image? = pack.imageName.map { Image($0) }
    return FCPackRow(name: pack.name, meta: pack.detail) {
      store.send(.view(.packTapped(pack.id)))
    }
    .image(image)
    .hasUpdate(pack.hasUpdate)
    .allowsHitTesting(isPackNavigationAvailable)
  }

  var settings: some View {
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

  var information: some View {
    section("정보") {
      FCListRow("공지사항") { store.send(.view(.noticeTapped)) }
        .allowsHitTesting(isNoticeAvailable)
      rowDivider
      FCListRow("이용약관") { store.send(.view(.termsTapped)) }
      rowDivider
      FCListRow("개인정보 처리방침") { store.send(.view(.privacyTapped)) }
    }
  }

  enum AccountSheet: String, Identifiable {
    case account

    var id: String { rawValue }
  }

  var accountItem: Binding<AccountSheet?> {
    Binding(
      get: { store.isAccountPresented ? .account : nil },
      set: { if $0 == nil { store.send(.view(.accountDismissed)) } }
    )
  }

  @ViewBuilder
  var confirmationOverlay: some View {
    if store.isLegalLinkUnavailablePresented {
      confirmation(
        title: "문서를 열 수 없어요",
        message: "잠시 후 다시 시도해 주세요.",
        confirmTitle: "확인",
        onConfirm: { store.send(.view(.legalLinkUnavailableDismissed)) },
        onDismiss: { store.send(.view(.legalLinkUnavailableDismissed)) }
      )
    } else if store.isWithdrawalConfirmationPresented {
      confirmation(
        title: "회원 탈퇴",
        message: "계정과 로그인 정보가 삭제됩니다. 이 작업은 되돌릴 수 없습니다.",
        confirmTitle: "탈퇴",
        onConfirm: { store.send(.view(.confirmWithdrawTapped)) },
        onDismiss: { store.send(.view(.withdrawalConfirmationDismissed)) }
      )
    } else if store.isLogoutConfirmationPresented {
      confirmation(
        title: "로그아웃",
        message: "이 기기에서 로그아웃하시겠습니까?",
        confirmTitle: "로그아웃",
        onConfirm: { store.send(.view(.confirmLogoutTapped)) },
        onDismiss: { store.send(.view(.logoutConfirmationDismissed)) }
      )
    }
  }

  func confirmation(
    title: String,
    message: String,
    confirmTitle: String,
    onConfirm: @escaping () -> Void,
    onDismiss: @escaping () -> Void
  ) -> some View {
    FCDialogOverlay(
      item: FCDialogItem(
        title: title,
        message: message,
        confirmTitle: confirmTitle,
        onConfirm: onConfirm,
        onCancel: {}
      ),
      dismissesOnDimTap: true,
      onDismiss: onDismiss
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
