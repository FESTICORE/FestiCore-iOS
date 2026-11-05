//
//  AppAuthFlow.swift
//  FestiCore
//

import AuthDomainInterface
import FeatureAssembly
import Foundation

extension AppCoordinator {
  struct AuthFlow: Equatable {
    enum Presentation: Equatable {
      case login
      case onboarding
      case migration
      case retry
    }

    var pendingFestivalID: String?
    var pendingShouldBeBooked = true
    var pendingOwnerID: String?
    var generation = 0
    var accountOperationGeneration: Int?
    var accountOperation: MyAccountOperation?
    var loginAttemptGeneration: Int?
    /// 수락해 확정 중인 로그인 세션. 확정 전에 시트가 닫히면 이 세션을 버린다.
    var pendingCommitSessionID: UUID?
    var verifiedUserID: String?
    var lastVerifiedUserID: String?
    var hasSession = false
    var profile: AuthProfile? {
      didSet {
        signUp.currentUserID = profile?.user.id
        signUp.currentTermsVersion = profile?.currentTermsVersion
      }
    }
    var presentation: Presentation?
    var loginContextOverride: LoginFeature.State.Context?
    var signUpFlow = SignUpFlowCoordinator.State()
    var signUp: SignUpFeature.State {
      get { signUpFlow.signUp }
      set { signUpFlow.signUp = newValue }
    }
    var isLoading = false
    var hasRetriedTermsUpdate = false
    var termsUpdateExhausted = false
    var message: String?

    mutating func dropUnownedPendingBookmark() {
      guard pendingOwnerID == nil else { return }
      pendingFestivalID = nil
      pendingShouldBeBooked = false
    }

    mutating func clearSignUpDraft() {
      signUp.clearDraft()
      resetSignUpRetryState()
    }

    mutating func reconcileSignUpDraft(userID: String) {
      if signUp.reconcile(userID: userID) { resetSignUpRetryState() }
    }

    mutating func resetSignUpRetryState() {
      message = nil
      hasRetriedTermsUpdate = false
      termsUpdateExhausted = false
    }
  }

  enum ProfileFailure: Error, Equatable, Sendable {
    case unauthenticated
    case offline
    case termsOutdated
    case unavailable

    init(_ error: Error) {
      guard let domain = error as? AuthDomainError else {
        self = .unavailable
        return
      }
      switch domain {
      case .notAuthenticated:
        self = .unauthenticated
      case .offline: self = .offline
      case .termsOutdated: self = .termsOutdated
      default: self = .unavailable
      }
    }
  }

  enum CancelID { case sessionExpiry, accountOperation, widgetSnapshot }

  enum MyAccountOperation: Equatable, Sendable {
    case signOut
    case withdraw
  }
}
