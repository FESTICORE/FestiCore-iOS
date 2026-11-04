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

struct AppCoordinatorView: View {
  @Bindable var store: StoreOf<AppCoordinator>
  @Environment(\.scenePhase) private var scenePhase

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

      case .onboarding:
        if let onboardingStore = store.scope(\.onboarding, action: \.scope.onboarding) {
          OnboardingView(store: onboardingStore)
            .transition(.opacity)
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
      if phase == .background { store.send(.view(.backgrounded)) }
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

  @ViewBuilder
  var loginSheet: some View {
    if let loginStore = store.scope(\.home, action: \.scope.home)?.scope(state: \.loginState, action: \.login) {
      LoginView(store: loginStore)
    }
  }

  @ViewBuilder
  var onboardingSheet: some View {
    if let signUpStore = store.scope(\.home, action: \.scope.home)?.scope(state: \.authFlow.signUp, action: \.signUp) {
      SignUpView(store: signUpStore)
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
