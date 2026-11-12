//
//  AuthFlowState.swift
//  FestiCore
//
//  Created by FestiCore on 10/23/26.
//

import AuthDomainInterface
import ComposableArchitecture
import FeatureAssembly
import Foundation

/// 홈 위에 뜨는 로그인·가입·이전 시트와 그 사이 대기 예약, 계정 확인 상태를 담는다.
/// 세션·로그인·계정 코디네이터가 같은 값을 함께 쓰며, 각 코디네이터는 자기 액션의 범위에서만 이 상태를 바꾼다.
@ObservableState
struct AuthFlowState: Equatable {
  enum Presentation: Equatable {
    case login
    /// 로그아웃 상태로 앱을 켰을 때 홈 위를 덮는 S14 A 로그인 첫 진입 화면
    case launchLogin
    /// 마이 로그인 카드처럼 화면에서 제공자를 이미 고른 로그인. 시트 없이 Apple·Google 로그인 창만 띄운다.
    case directLogin
    case onboarding
    /// 가입을 마친 뒤 같은 가입 스택에서 이어 가는 기수 여부·깃발 등록·저장 완료(S14 C~E)
    case bearerSetup
    case migration
    case retry

    /// 로그인 시트·첫 진입 화면이 떠 있거나 바로 로그인 중이라 로그인 결과를 받을 수 있다.
    var acceptsLogin: Bool {
      return self == .login || self == .launchLogin || self == .directLogin
    }
  }

  var pendingFestivalID: String?
  var pendingShouldBeBooked = true
  var pendingOwnerID: String?
  var generation = 0
  var accountOperationGeneration: Int?
  var accountOperation: AccountCoordinator.Operation?
  var loginAttemptGeneration: Int?
  /// 수락해 확정 중인 로그인 세션. 확정 전에 시트가 닫히면 이 세션을 버린다.
  var pendingCommitSessionID: UUID?
  var verifiedUserID: String?
  var lastVerifiedUserID: String?
  var hasSession = false
  /// 관찰 추적 접근자 대신 didSet을 유지하려고 추적에서 뺀다. 화면은 이 값을 직접 읽지 않는다.
  @ObservationStateIgnored
  var profile: AuthProfile? {
    // 가입 초안 규칙이 현재 계정과 약관 버전을 따르도록 프로필이 바뀔 때마다 알린다.
    didSet {
      signUp.currentUserID = profile?.user.id
      signUp.currentTermsVersion = profile?.currentTermsVersion
    }
  }
  var presentation: Presentation?
  /// 첫 진입 화면(S14 A)에서 로그인했다. 가입 정보·기수 설정을 마칠 때까지 메인 탭 대신 첫 진입 화면 위에 이어 그린다.
  var isLaunchFlow = false
  var loginContextOverride: LoginFeature.State.Context?
  var login = LoginFeature.State()
  /// 가입 정보 초안과 약관 상세 push 경로
  var signUpFlow = AuthCoordinator.SignUpFlow()
  var signUp: SignUpFeature.State {
    get { signUpFlow.signUp }
    set { signUpFlow.signUp = newValue }
  }
  var isLoading = false
  var hasRetriedTermsUpdate = false
  var termsUpdateExhausted = false
  var message: String?
}

// MARK: - 첫 진입 흐름

extension AuthFlowState {
  /// 첫 진입 화면이나 그 화면에서 이어진 계정 확인·가입·기수 설정이 메인 탭을 덮는다.
  /// 로그인 직후 계정을 확인하는 동안에도 덮어 홈이 잠깐 보이지 않게 한다.
  var coversMainTab: Bool {
    if presentation == .launchLogin { return true }
    guard isLaunchFlow else { return false }
    switch presentation {
    case .onboarding, .bearerSetup:
      return true
    case nil:
      return isLoading
    case .login, .launchLogin, .directLogin, .migration, .retry:
      return false
    }
  }

  /// 첫 진입 화면 위에 가입 정보(S14 B)부터 기수 설정(S14 C~E)까지 push 흐름을 그린다.
  var showsLaunchSignUp: Bool {
    return isLaunchFlow && (presentation == .onboarding || presentation == .bearerSetup)
  }
}

// MARK: - 요청 세대

extension AuthFlowState {
  /// 새 요청 세대를 열고 로딩을 표시한다. 이전 세대의 응답은 무시된다.
  mutating func beginRequest() -> Int {
    generation += 1
    isLoading = true
    return generation
  }
}

// MARK: - 대기 예약

extension AuthFlowState {
  /// 대기 예약을 계정에 마저 반영할지, 예약 목록만 다시 읽을지 나타낸다.
  enum PendingBookmarkResolution: Equatable {
    case reloadBookmarks(userID: String)
    case complete(
      id: String,
      userID: String,
      shouldBeBooked: Bool
    )
  }

  mutating func clearPendingBookmark() {
    pendingFestivalID = nil
    pendingOwnerID = nil
  }

  /// 대기 예약을 꺼내고 비운다. 예약이 있으면 `userID` 계정으로 마저 반영하고, 없으면 예약 목록만 다시 읽게 한다.
  mutating func resolvePendingBookmark(userID: String) -> PendingBookmarkResolution {
    let id = pendingFestivalID
    let shouldBeBooked = pendingShouldBeBooked
    clearPendingBookmark()
    guard let id else { return .reloadBookmarks(userID: userID) }
    return .complete(
      id: id,
      userID: userID,
      shouldBeBooked: shouldBeBooked
    )
  }

  /// 요청 계정을 모르는 대기 예약은 다른 계정에 적용되지 않도록 버린다.
  mutating func dropUnownedPendingBookmark() {
    guard pendingOwnerID == nil else { return }
    pendingFestivalID = nil
    pendingShouldBeBooked = false
  }

  /// 다른 계정이 요청한 대기 예약을 버린다.
  mutating func dropPendingBookmark(notOwnedBy userID: String) {
    guard let ownerID = pendingOwnerID, ownerID != userID else { return }
    clearPendingBookmark()
  }
}

// MARK: - 계정

extension AuthFlowState {
  /// 이전에 확인한 계정이 있고 그 계정이 `userID`와 다르다.
  func isAccountChanged(to userID: String) -> Bool {
    return [verifiedUserID, lastVerifiedUserID].contains { $0 != nil && $0 != userID }
  }

  /// 진행 중이던 로그아웃·탈퇴 표시를 지운다.
  mutating func endAccountOperation() {
    accountOperationGeneration = nil
    accountOperation = nil
  }

  /// 인증을 잃었을 때 확인한 계정과 프로필을 지운다.
  mutating func forgetVerifiedAccount() {
    verifiedUserID = nil
    lastVerifiedUserID = nil
    hasSession = false
    profile = nil
  }
}

// MARK: - 가입 초안

extension AuthFlowState {
  /// 계정이 바뀌거나 로그인을 잃을 때 가입 초안과 이전 계정의 재시도 상태·문구를 함께 지운다.
  mutating func clearSignUpDraft() {
    signUp.clearDraft()
    resetSignUpRetryState()
  }

  /// 계정이 확인될 때 다른 계정이 만들었거나 소유자를 모르는 초안은 재시도 상태와 함께 버린다.
  mutating func reconcileSignUpDraft(userID: String) {
    if signUp.reconcile(userID: userID) { resetSignUpRetryState() }
  }

  mutating func resetSignUpRetryState() {
    message = nil
    hasRetriedTermsUpdate = false
    termsUpdateExhausted = false
  }
}

// MARK: - 문구

extension AuthFlowState {
  enum Message {
    static let sessionExpiredDuringWithdraw = "로그인이 만료되어 회원 탈퇴 결과를 확인할 수 없어요. 다시 로그인해 계정 상태를 확인해 주세요."
    static let termsChangedReconsent = "변경된 약관을 확인하고 다시 동의해 주세요."
    static let offlineProfile = "오프라인에서 계정 정보를 확인할 수 없어요. 연결 후 다시 시도해 주세요."
    static let profileUnavailable = "회원 정보를 확인할 수 없어요. 다시 시도해 주세요."
    static let requiredInfoMissing = "필수 정보가 확인되지 않았어요. 다시 시도해 주세요."
    static let termsChangedAgain = "약관이 다시 변경됐어요. 나중에 다시 시도해 주세요."
    static let termsChanged = "약관이 변경됐어요. 내용을 확인하고 다시 동의해 주세요."
    static let saveOffline = "오프라인에서 저장하지 못했어요. 연결 후 다시 시도해 주세요."
    static let saveFailed = "저장하지 못했어요. 다시 시도해 주세요."
    static let loginSaveFailed = "로그인 정보를 저장하지 못했어요. 다시 시도해 주세요."
    static let invalidNickname = "닉네임은 1~12자로 입력해 주세요."
    static let withdrawFailed = "회원 탈퇴에 실패했습니다. 다시 시도해 주세요."
    static let signOutFailed = "로그아웃에 실패했습니다. 다시 시도해 주세요."
  }
}
