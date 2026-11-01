//
//  AppCoordinatorView.swift
//  FestiCore
//
//  Created by FestiCore on 10/23/26.
//

import ComposableArchitecture
import FestiCoreDesignKit
import FestiCoreSharedUI
import SwiftUI
import UIKit

struct AppCoordinatorView: View {
  @Bindable var store: StoreOf<AppCoordinator>
  @Environment(\.scenePhase) private var scenePhase
  @Environment(\.openURL) private var openURL
  @State private var keyboardInset: CGFloat = 0

  private enum AuthSheet: String, Identifiable {
    case login, onboarding, migration, retry
    var id: String { rawValue }
  }

  var body: some View {
    ZStack(alignment: .topLeading) {
      Color.backgroundNormal
        .ignoresSafeArea()

      switch store.state {
      case .splash:
        if let splashStore = store.scope(\.splash, action: \.scope.splash) {
          SplashView(store: splashStore)
            .transition(.opacity.combined(with: .scale(scale: 0.98)))
        }

      case .home:
        if let homeStore = store.scope(\.home, action: \.scope.home) {
          MainTabView(store: homeStore)
            .transition(.asymmetric(
              insertion: .move(edge: .trailing),
              removal: .move(edge: .leading)
            ))
        }
      }
    }
    .animation(
      .spring(response: 0.52, dampingFraction: 0.94, blendDuration: 0.14),
      value: store.state.animationID
    )
    .presentFCSheet(item: sheet, height: sheet.wrappedValue == .onboarding ? .fraction(1) : .auto) { sheet in
      switch sheet {
      case .login: loginSheet
      case .onboarding: onboardingSheet
      case .migration: migrationSheet
      case .retry: retrySheet
      }
    }
    .onChange(of: scenePhase) { _, phase in
      if phase == .active { store.send(.view(.foregrounded)) }
    }
    .onReceive(NotificationCenter.default.publisher(for: UIResponder.keyboardWillChangeFrameNotification)) { notification in
      guard let frame = notification.userInfo?[UIResponder.keyboardFrameEndUserInfoKey] as? CGRect else { return }
      keyboardInset = max(0, UIScreen.main.bounds.height - frame.minY)
    }
    .onReceive(NotificationCenter.default.publisher(for: UIResponder.keyboardWillHideNotification)) { _ in
      keyboardInset = 0
    }
  }
}

private extension AppCoordinatorView {
  private var sheet: Binding<AuthSheet?> {
    Binding(
      get: {
        guard case let .home(home) = store.state else { return nil }
        switch home.authFlow.presentation {
        case .login: return .login
        case .onboarding: return .onboarding
        case .migration: return .migration
        case .retry: return .retry
        case nil: return nil
        }
      },
      set: { value in
        if value == nil { store.send(.view(.dismissFlow)) }
      }
    )
  }

  var loginSheet: some View {
    VStack {
      FCLoginSheet(
        title: loginCopy.title,
        message: loginCopy.message,
        onApple: { store.send(.view(.startLogin(.apple))) },
        onGoogle: { store.send(.view(.startLogin(.google))) }
      )
      if case let .home(home) = store.state,
         let message = home.authFlow.message ?? home.loginState.errorMessage {
        Text(message)
          .foregroundStyle(.red)
          .padding(.bottom, 16)
      }
    }
  }

  /// Figma S14-2 가입 정보(닉네임·약관 동의)
  var onboardingSheet: some View {
    VStack(spacing: .zero) {
      FCTopBar(.back)
        .onBack { store.send(.view(.dismissFlow)) }
      ScrollView {
        VStack(alignment: .leading, spacing: FestiCoreSpacing.paddingP24) {
          Text("반가워요!\n어떻게 불러 드릴까요?")
            .festiCoreFont(.baseTitle2Bold)
            .foregroundStyle(FestiCoreSemanticColor.labelNormal.color)
            .frame(maxWidth: .infinity, alignment: .leading)
          FCTextField(
            text: Binding(
              get: { currentFlow?.nickname ?? "" },
              set: { store.send(.view(.nicknameChanged($0))) }
            ),
            placeholder: "닉네임"
          )
          .label("닉네임")
          .maxLength(12)
          .helper("크루원과 깃발에 보이는 이름이에요. 나중에 마이에서 바꿀 수 있어요.")
          consentBox
          if let message = currentFlow?.message {
            Text(message)
              .festiCoreFont(.baseCaption1Regular)
              .foregroundStyle(FestiCoreSemanticColor.statusNegative.color)
          }
        }
        .padding(FestiCoreSpacing.paddingP16)
      }
      .scrollDismissesKeyboard(.interactively)
      FCPrimaryButton("시작하기", isEnabled: canSubmitOnboarding) {
        store.send(.view(.submitOnboarding))
      }
      .padding(.horizontal, FestiCoreSpacing.paddingP16)
      .padding(.top, FestiCoreSpacing.paddingP12)
      .padding(.bottom, FestiCoreSpacing.paddingP8)
    }
    .padding(.bottom, keyboardInset)
  }

  var consentBox: some View {
    VStack(spacing: .zero) {
      FCConsentAll(isChecked: currentFlow?.isAllConsented ?? false) {
        store.send(.view(.allConsentToggled))
      }
      FestiCoreSemanticColor.lineNormal.color
        .frame(height: 1)
      VStack(spacing: .zero) {
        FCConsentRow("서비스 이용약관", isChecked: currentFlow?.acceptedServiceTerms ?? false) {
          store.send(.view(.serviceTermsChanged(!(currentFlow?.acceptedServiceTerms ?? false))))
        }
        .tag("필수")
        .onDetail(legalLink("terms"))
        FCConsentRow("개인정보 수집 · 이용", isChecked: currentFlow?.acceptedPrivacyTerms ?? false) {
          store.send(.view(.privacyTermsChanged(!(currentFlow?.acceptedPrivacyTerms ?? false))))
        }
        .tag("필수")
        .onDetail(legalLink("privacy"))
        FCConsentRow("알림 받기", isChecked: currentFlow?.pushOptIn ?? false) {
          store.send(.view(.pushOptInChanged(!(currentFlow?.pushOptIn ?? false))))
        }
        .tag("선택")
        .sub("공연 10분 전 · 팔로우한 깃발 · 크루 소식")
      }
      .padding(.vertical, FestiCoreSpacing.paddingP8)
    }
    .overlay {
      RoundedRectangle(cornerRadius: FestiCoreRadius.r16)
        .strokeBorder(FestiCoreSemanticColor.lineNormal.color, lineWidth: 1)
    }
  }

  var canSubmitOnboarding: Bool {
    guard let flow = currentFlow else { return false }
    return !flow.isLoading
      && !flow.termsUpdateExhausted
      && flow.acceptedTerms
      && flow.consentedVersion == flow.profile?.currentTermsVersion
      && legalBaseURL != nil
      && !flow.nickname.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
  }

  /// 약관 상세 링크. 기준 주소가 없으면 화살표를 숨긴다.
  func legalLink(_ path: String) -> (() -> Void)? {
    guard let baseURL = legalBaseURL else { return nil }
    return { openURL(baseURL.appending(path: path)) }
  }

  var migrationSheet: some View {
    VStack(alignment: .leading, spacing: 16) {
      Text("기존 축제 저장 목록")
        .font(.title2.bold())
      Text("이 기기에 저장된 축제 목록을 현재 계정으로 가져올까요? 가져오지 않으면 기존 목록은 삭제돼요.")
      Button("가져오기") { store.send(.view(.resolveMigration(true))) }
        .buttonStyle(.borderedProminent)
      Button("가져오지 않고 삭제") { store.send(.view(.resolveMigration(false))) }
        .buttonStyle(.plain)
    }
    .padding(24)
  }

  var retrySheet: some View {
    VStack(alignment: .leading, spacing: 16) {
      Text(currentFlow?.message ?? "회원 정보를 확인할 수 없어요.")
      Button("다시 시도") { store.send(.view(.retryProfile)) }
        .buttonStyle(.borderedProminent)
        .disabled(currentFlow?.isLoading == true)
      Button("취소") { store.send(.view(.dismissFlow)) }
        .buttonStyle(.plain)
    }
    .padding(24)
  }

  var currentFlow: AppCoordinator.AuthFlow? {
    guard case let .home(home) = store.state else { return nil }
    return home.authFlow
  }

  /// 로그인을 요청한 탭에 맞춘 시트 문구
  var loginCopy: (title: String, message: String) {
    guard case let .home(home) = store.state else {
      return ("축제를 저장하려면 로그인이 필요해요", "로그인 후 선택한 축제를 저장할 수 있어요.")
    }
    switch home.selectedTab {
    case .my:
      return ("계정 정보를 보려면 로그인이 필요해요", "로그인 후 프로필을 확인할 수 있어요.")
    case .flag:
      return ("깃발을 팔로우 하려면 로그인이 필요해요", "내 취향의 깃발을 팔로우하고,\n함께 페스티벌을 즐길 사람들과 크루를 만들어봐요.")
    case .live, .timetable:
      return ("축제를 저장하려면 로그인이 필요해요", "로그인 후 선택한 축제를 저장할 수 있어요.")
    }
  }

  var legalBaseURL: URL? {
    Self.legalBaseURL(host: Bundle.main.object(forInfoDictionaryKey: "FestiCoreAPIHost") as? String)
  }
}

extension AppCoordinatorView {
  nonisolated static func legalBaseURL(host: String?) -> URL? {
    guard let host, !host.isEmpty else { return nil }
    return URL(string: "https://\(host)/api/v1/legal/")
  }
}

#Preview {
  AppCoordinatorView(
    store: Store(initialState: AppCoordinator.State()) {
      AppCoordinator()
    }
  )
}
