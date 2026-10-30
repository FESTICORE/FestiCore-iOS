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
    .presentFCSheet(item: sheet) { sheet in
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
        title: currentTabIsMy ? "계정 정보를 보려면 로그인이 필요해요" : "축제를 저장하려면 로그인이 필요해요",
        message: currentTabIsMy ? "로그인 후 프로필을 확인할 수 있어요." : "로그인 후 선택한 축제를 저장할 수 있어요.",
        onApple: { store.send(.view(.startLogin(.apple))) },
        onGoogle: { store.send(.view(.startLogin(.google))) }
      )
      if case let .home(home) = store.state,
         let message = home.loginState.errorMessage {
        Text(message)
          .foregroundStyle(.red)
          .padding(.bottom, 16)
      }
    }
  }

  var onboardingSheet: some View {
    ScrollView {
      VStack(alignment: .leading, spacing: 16) {
        Text("가입을 완료해 주세요")
          .font(.title2.bold())
        Text("축제를 저장하려면 약관에 동의하고 닉네임을 설정해야 해요.")
        TextField("닉네임 (1~12자)", text: Binding(
          get: { currentFlow?.nickname ?? "" },
          set: { store.send(.view(.nicknameChanged($0))) }
        ))
        .textInputAutocapitalization(.never)
        .autocorrectionDisabled()
        .textFieldStyle(.roundedBorder)
        HStack {
          Toggle("이용약관 및 개인정보처리방침에 동의해요 (필수)", isOn: Binding(
            get: { currentFlow?.acceptedTerms ?? false },
            set: { store.send(.view(.termsAcceptanceChanged($0))) }
          ))
        }
        if let baseURL = legalBaseURL {
          HStack(spacing: 20) {
            Link("이용약관 보기", destination: baseURL.appending(path: "terms"))
            Link("개인정보처리방침 보기", destination: baseURL.appending(path: "privacy"))
          }
          .font(.footnote)
        }
        Toggle("알림 받기 (선택)", isOn: Binding(
          get: { currentFlow?.pushOptIn ?? false },
          set: { store.send(.view(.pushOptInChanged($0))) }
        ))
        if let message = currentFlow?.message {
          Text(message).foregroundStyle(.red)
        }
        Button("완료하고 축제 저장") {
          store.send(.view(.submitOnboarding))
        }
        .buttonStyle(.borderedProminent)
        .disabled(
          currentFlow?.isLoading == true
            || currentFlow?.termsUpdateExhausted == true
            || currentFlow?.acceptedTerms != true
            || currentFlow?.consentedVersion != currentFlow?.profile?.currentTermsVersion
            || legalBaseURL == nil
        )
        Button("나중에 하기") { store.send(.view(.dismissFlow)) }
          .buttonStyle(.plain)
      }
      .padding(24)
    }
    .frame(maxHeight: max(180, min(540, UIScreen.main.bounds.height - keyboardInset - 80)))
    .padding(.bottom, keyboardInset)
    .scrollDismissesKeyboard(.interactively)
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

  var currentTabIsMy: Bool {
    guard case let .home(home) = store.state else { return false }
    return home.selectedTab == .my
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
