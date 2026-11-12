//
//  AuthCoordinatorView.swift
//  FestiCore
//

import ComposableArchitecture
import FeatureAssembly
import SwiftUI
import TCAFlow

/// 홈 위에 뜨는 로그인·가입·이전 확인·재시도 시트의 내용
@ViewAction(for: AuthCoordinator.self)
struct AuthCoordinatorView: View {
  @Bindable var store: StoreOf<AuthCoordinator>
  let sheet: Sheet

  var body: some View {
    switch sheet {
    case .login:
      LoginView(store: store.scope(
        state: \.login,
        action: \.login
      ))
    case .onboarding:
      signUpFlow
    case .migration:
      migrationSheet()
    case .retry:
      retrySheet()
    }
  }
}

extension AuthCoordinatorView {
  enum Sheet: String, Identifiable {
    case login, onboarding, migration, retry
    var id: String { return rawValue }

    init?(_ presentation: AuthCoordinator.State.Presentation?) {
      switch presentation {
      case .login: self = .login
      case .onboarding: self = .onboarding
      case .migration: self = .migration
      case .retry: self = .retry
      // 첫 진입 화면은 시트가 아니라 MainTabView가 전체 화면으로 덮는다.
      // 바로 로그인은 시트 없이 Apple·Google 창만 띄운다.
      case .launchLogin, .directLogin, nil: return nil
      }
    }
  }
}

private extension AuthCoordinatorView {
  var signUpFlow: some View {
    TCAFlowRouter(store.scope(
      \.signUpFlow.routes,
      action: \.signUp.router
    )) { screen in
      switch screen.case {
      case let .signUp(signUpStore):
        SignUpView(store: signUpStore)
      case let .legalDocument(webStore):
        WebView(store: webStore)
          .swipeBackButtonHidden()
          .toolbar(
            .hidden,
            for: .navigationBar
          )
      }
    }
  }

  @ViewBuilder
  func migrationSheet() -> some View {
    VStack(
      alignment: .leading,
      spacing: 16
    ) {
      Text("기존 축제 저장 목록")
        .font(.title2.bold())
      Text("이 기기에 저장된 축제 목록을 현재 계정으로 가져올까요? 가져오지 않으면 기존 목록은 삭제돼요.")
      Button("가져오기") { send(.resolveMigration(true)) }
        .buttonStyle(.borderedProminent)
      Button("가져오지 않고 삭제") { send(.resolveMigration(false)) }
        .buttonStyle(.plain)
    }
    .padding(24)
  }

  @ViewBuilder
  func retrySheet() -> some View {
    VStack(
      alignment: .leading,
      spacing: 16
    ) {
      Text(store.message ?? "회원 정보를 확인할 수 없어요.")
      Button("다시 시도") { send(.retryTapped) }
        .buttonStyle(.borderedProminent)
        .disabled(store.isLoading)
      Button("취소") { send(.dismissFlow) }
        .buttonStyle(.plain)
    }
    .padding(24)
  }
}
