//
//  AppCoordinatorView.swift
//  FestiCore
//
//  Created by FestiCore on 10/23/26.
//

import ComposableArchitecture
import FeatureAssembly
import FestiCoreDesignKit
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
    // 가입 화면은 Figma처럼 그래버 없이 화면 높이로 연다. 그래버와 간격만큼 상단 안전 영역을 넘지 않는다.
    .presentFCSheet(
      item: sheet,
      height: sheet.wrappedValue == .onboarding ? .fraction(1) : .auto,
      showsGrabber: sheet.wrappedValue != .onboarding
    ) { sheet in
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
    LoginView(
      title: loginCopy.title,
      message: loginCopy.message,
      errorMessage: currentFlow?.message ?? loginErrorMessage,
      onApple: { store.send(.view(.startLogin(.apple))) },
      onGoogle: { store.send(.view(.startLogin(.google))) }
    )
  }

  @ViewBuilder
  var onboardingSheet: some View {
    if let signUpStore = store.scope(\.home, action: \.scope.home)?.scope(state: \.authFlow.signUp, action: \.signUp) {
      SignUpView(
        store: signUpStore,
        isSubmitting: currentFlow?.isLoading ?? false,
        message: currentFlow?.message,
        termsUpdateExhausted: currentFlow?.termsUpdateExhausted ?? false,
        legalBaseURL: legalBaseURL,
        keyboardInset: keyboardInset,
        onLegalLink: { document in
          guard let legalBaseURL else { return }
          openURL(legalBaseURL.appending(path: document.path))
        }
      )
    }
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

  var loginErrorMessage: String? {
    guard case let .home(home) = store.state else { return nil }
    return home.loginState.errorMessage
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
