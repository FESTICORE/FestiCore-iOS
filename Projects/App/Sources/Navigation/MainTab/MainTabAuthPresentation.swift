//
//  MainTabAuthPresentation.swift
//  FestiCore
//

import ComposableArchitecture
import FeatureAssembly
import FestiCoreDesignKit
import SwiftUI

extension MainTabView {
  enum AuthSheet: String, Identifiable {
    case login, onboarding, migration, retry
    var id: String { return rawValue }
  }

  var authSheet: Binding<AuthSheet?> {
    return Binding(
      get: {
        switch store.authFlow.presentation {
        case .login: return .login
        case .onboarding: return .onboarding
        case .migration: return .migration
        case .retry: return .retry
        case nil: return nil
        }
      },
      set: { value in
        if value == nil { store.send(.delegate(.dismissAuthFlow)) }
      }
    )
  }

  @ViewBuilder
  func authSheetContent(_ sheet: AuthSheet) -> some View {
    switch sheet {
    case .login:
      LoginView(store: store.scope(
        state: \.loginState,
        action: \.login
      ))
    case .onboarding:
      SignUpFlowCoordinatorView(store: store.scope(
        state: \.authFlow.signUpFlow,
        action: \.signUp
      ))
    case .migration:
      migrationSheet
    case .retry:
      retrySheet
    }
  }
}

private extension MainTabView {
  var migrationSheet: some View {
    VStack(
      alignment: .leading,
      spacing: 16
    ) {
      Text("기존 축제 저장 목록")
        .font(.title2.bold())
      Text("이 기기에 저장된 축제 목록을 현재 계정으로 가져올까요? 가져오지 않으면 기존 목록은 삭제돼요.")
      Button("가져오기") { store.send(.delegate(.resolveMigration(true))) }
        .buttonStyle(.borderedProminent)
      Button("가져오지 않고 삭제") { store.send(.delegate(.resolveMigration(false))) }
        .buttonStyle(.plain)
    }
    .padding(24)
  }

  var retrySheet: some View {
    VStack(
      alignment: .leading,
      spacing: 16
    ) {
      Text(store.authFlow.message ?? "회원 정보를 확인할 수 없어요.")
      Button("다시 시도") { store.send(.delegate(.retryProfile)) }
        .buttonStyle(.borderedProminent)
        .disabled(store.authFlow.isLoading)
      Button("취소") { store.send(.delegate(.dismissAuthFlow)) }
        .buttonStyle(.plain)
    }
    .padding(24)
  }
}
