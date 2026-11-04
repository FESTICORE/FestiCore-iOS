//
//  MainTabAuthInputs.swift
//  FestiCore
//

import AuthDomainInterface
import FeatureAssembly

extension MainTabCoordinator {
  /// 홈 화면의 자식 기능에 전달하는 인증 입력만 모은다.
  struct AuthInputs: Equatable {
    struct Login: Equatable {
      let context: LoginFeature.State.Context
      let message: String?
    }

    struct SignUp: Equatable {
      let isSubmitting: Bool
      let message: String?
      let termsUpdateExhausted: Bool
    }

    struct Session: Equatable {
      let hasSession: Bool
      let userID: String?
    }

    struct Account: Equatable {
      let profile: AuthProfile?
      let hasSession: Bool
      let isLoading: Bool
      let message: String?
    }

    let login: Login?
    let signUp: SignUp?
    let session: Session
    let account: Account
  }
}

extension MainTabCoordinator.State {
  var authInputs: MainTabCoordinator.AuthInputs {
    let flow = authFlow
    let login: MainTabCoordinator.AuthInputs.Login?
    if flow.presentation == .login {
      let context: LoginFeature.State.Context = switch selectedTab {
      case .my: .profile
      case .flag: .flag
      case .live, .timetable: .bookmark
      }
      login = .init(
        context: flow.loginContextOverride ?? context,
        message: flow.message
      )
    } else {
      login = nil
    }

    let signUp: MainTabCoordinator.AuthInputs.SignUp? = flow.presentation == .onboarding
      ? .init(
        isSubmitting: flow.isLoading,
        message: flow.message,
        termsUpdateExhausted: flow.termsUpdateExhausted
      )
      : nil

    return .init(
      login: login,
      signUp: signUp,
      session: .init(
        hasSession: flow.hasSession,
        userID: flow.hasSession
          ? flow.profile?.user.id ?? flow.verifiedUserID ?? flow.lastVerifiedUserID
          : nil
      ),
      account: .init(
        profile: flow.profile,
        hasSession: flow.hasSession,
        isLoading: flow.isLoading,
        message: flow.message
      )
    )
  }
}
