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
        \.loginState,
        action: \.scopeAction.login
      ))
    case .onboarding:
      SignUpFlowCoordinatorView(store: store.scope(
        \.authFlow.signUpFlow,
        action: \.scopeAction.signUp
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
      spacing: FestiCoreSpacing.paddingP16
    ) {
      Text("기존 축제 저장 목록")
        .festiCoreFont(.baseHeadlineBold)
        .foregroundStyle(FestiCoreSemanticColor.labelNormal.color)
        .accessibilityAddTraits(.isHeader)
      Text("이 기기에 저장된 축제 목록을 현재 계정으로 가져올까요? 가져오지 않으면 기존 목록은 삭제돼요.")
        .festiCoreFont(.baseBodyRegular)
        .foregroundStyle(FestiCoreSemanticColor.labelNeutral.color)
      FCPrimaryButton("가져오기") {
        store.send(.delegate(.resolveMigration(true)))
      }
      FCButton("가져오지 않고 삭제") {
        store.send(.delegate(.resolveMigration(false)))
      }
      .style(.ghost)
      .isFullWidth(true)
    }
    .padding(FestiCoreSpacing.paddingP24)
  }

  var retrySheet: some View {
    VStack(
      alignment: .leading,
      spacing: FestiCoreSpacing.paddingP16
    ) {
      Text(store.authFlow.message ?? "회원 정보를 확인할 수 없어요.")
        .festiCoreFont(.baseBodyRegular)
        .foregroundStyle(FestiCoreSemanticColor.labelNormal.color)
      FCPrimaryButton(
        "다시 시도",
        isEnabled: !store.authFlow.isLoading
      ) {
        store.send(.delegate(.retryProfile))
      }
      FCButton("취소") {
        store.send(.delegate(.dismissAuthFlow))
      }
      .style(.ghost)
      .isFullWidth(true)
    }
    .padding(FestiCoreSpacing.paddingP24)
  }
}
