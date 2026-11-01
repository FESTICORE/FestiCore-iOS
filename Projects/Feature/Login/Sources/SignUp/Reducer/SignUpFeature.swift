//
//  SignUpFeature.swift
//  Login
//
//  Created by FestiCore on 11/2/26.
//

import ComposableArchitecture
import Foundation
import LoginInterface

/// 가입 정보(닉네임·약관 동의) 초안과 그 규칙. 제출·닫기는 부모가 처리하도록 delegate로 올린다.
@Reducer
public struct SignUpFeature {
  public init() {}

  @ObservableState
  public struct State: Equatable {
    /// 현재 확인된 계정. 부모가 프로필을 받거나 잃을 때 갱신한다.
    public var currentUserID: String?
    /// 현재 서버 약관 버전. 부모가 프로필을 받거나 잃을 때 갱신한다.
    public var currentTermsVersion: String?
    public var nickname = ""
    /// 사용자가 닉네임을 직접 고쳤는지. 고친 값(빈 값 포함)은 프로필 닉네임으로 덮어쓰지 않는다.
    public var nicknameEdited = false
    public var acceptedServiceTerms = false
    public var acceptedPrivacyTerms = false
    /// 필수 약관을 체크할 때의 약관 버전. 새 버전 프로필이 오면 체크를 지운다.
    public var termsDraftVersion: String?
    public var pushOptIn = false
    /// 가입 초안(닉네임·약관·알림)을 만든 계정. 계정이 확인될 때 다르면 초안을 버린다.
    public var draftOwnerID: String?

    public init() {}

    /// 두 필수 약관(서비스 이용약관·개인정보 수집 이용)이 모두 체크됐을 때만 true다.
    public var acceptedTerms: Bool {
      acceptedServiceTerms && acceptedPrivacyTerms
    }

    /// 두 필수 약관이 모두 체크됐을 때만 체크한 시점의 약관 버전에 동의한 것으로 본다.
    public var consentedVersion: String? {
      acceptedTerms ? termsDraftVersion : nil
    }

    public var isAllConsented: Bool {
      acceptedServiceTerms && acceptedPrivacyTerms && pushOptIn
    }

    var hasDraft: Bool {
      !nickname.isEmpty || nicknameEdited || acceptedServiceTerms || acceptedPrivacyTerms || pushOptIn
    }

    /// 계정이 확인될 때 다른 계정이 만들었거나 소유자를 모르는 초안은 버린다. 초안을 버렸으면 true다.
    @discardableResult
    public mutating func reconcile(userID: String) -> Bool {
      if hasDraft, draftOwnerID != userID {
        clearDraft()
        return true
      }
      if !hasDraft { draftOwnerID = nil }
      return false
    }

    /// 가입이 필요한 프로필을 받았을 때 서버 닉네임을 채우고, 약관 버전이 바뀌었으면 필수 체크를 지운다.
    public mutating func apply(profileUserID: String, serverNickname: String?, termsVersion: String) {
      currentUserID = profileUserID
      currentTermsVersion = termsVersion
      if !nicknameEdited, nickname.isEmpty, let serverNickname, !serverNickname.isEmpty {
        nickname = serverNickname
        claimDraft()
      }
      if let termsDraftVersion, termsDraftVersion != termsVersion {
        clearRequiredTerms()
      }
    }

    public mutating func clearDraft() {
      nickname = ""
      nicknameEdited = false
      pushOptIn = false
      draftOwnerID = nil
      clearRequiredTerms()
    }

    /// 약관 버전이 바뀌었을 때처럼 닉네임은 두고 필수 약관 체크만 지운다.
    public mutating func clearRequiredTerms() {
      acceptedServiceTerms = false
      acceptedPrivacyTerms = false
      termsDraftVersion = nil
    }

    /// 시트를 닫을 때 닉네임·알림·소유자는 두고 필수 약관 체크만 지운다.
    public mutating func resetForDismissal() {
      clearRequiredTerms()
    }

    /// 초안을 처음 바꿀 때 현재 계정을 소유자로 기록한다.
    mutating func claimDraft() {
      if draftOwnerID == nil { draftOwnerID = currentUserID }
    }

    /// 필수 약관을 처음 체크할 때의 약관 버전을 기록하고, 모두 해제하면 지운다.
    mutating func syncRequiredTerms() {
      if acceptedServiceTerms || acceptedPrivacyTerms {
        if termsDraftVersion == nil { termsDraftVersion = currentTermsVersion }
      } else {
        termsDraftVersion = nil
      }
    }
  }

  @CasePathable
  public enum Action: ViewAction, Equatable {
    case view(View)
    case delegate(SignUpDelegate)
  }

  @CasePathable
  public enum View: Equatable {
    case nicknameChanged(String)
    case termsAcceptanceChanged(Bool)
    case serviceTermsChanged(Bool)
    case privacyTermsChanged(Bool)
    case allConsentToggled
    case pushOptInChanged(Bool)
    case submitTapped
    case closeTapped
  }

  public var body: some ReducerOf<Self> {
    Reduce { state, action in
      switch action {
      case let .view(.nicknameChanged(nickname)):
        state.claimDraft()
        state.nickname = nickname
        state.nicknameEdited = true
        return .none

      case let .view(.termsAcceptanceChanged(accepted)):
        state.claimDraft()
        state.acceptedServiceTerms = accepted
        state.acceptedPrivacyTerms = accepted
        state.syncRequiredTerms()
        return .none

      case let .view(.serviceTermsChanged(accepted)):
        state.claimDraft()
        state.acceptedServiceTerms = accepted
        state.syncRequiredTerms()
        return .none

      case let .view(.privacyTermsChanged(accepted)):
        state.claimDraft()
        state.acceptedPrivacyTerms = accepted
        state.syncRequiredTerms()
        return .none

      case .view(.allConsentToggled):
        state.claimDraft()
        let accepted = !state.isAllConsented
        state.acceptedServiceTerms = accepted
        state.acceptedPrivacyTerms = accepted
        state.pushOptIn = accepted
        state.syncRequiredTerms()
        return .none

      case let .view(.pushOptInChanged(optedIn)):
        state.claimDraft()
        state.pushOptIn = optedIn
        return .none

      case .view(.submitTapped):
        let nickname = state.nickname.trimmingCharacters(in: .whitespacesAndNewlines)
        return .send(.delegate(.submitRequested(SignUpSubmission(
          nickname: nickname,
          pushOptIn: state.pushOptIn,
          isNicknameValid: (1 ... 12).contains(nickname.count)
        ))))

      case .view(.closeTapped):
        return .send(.delegate(.closeRequested))

      case .delegate:
        return .none
      }
    }
  }
}
