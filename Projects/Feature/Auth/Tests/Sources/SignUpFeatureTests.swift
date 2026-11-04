//
//  SignUpFeatureTests.swift
//  AuthTests
//
//  Created by FestiCore on 11/2/26.
//

import ComposableArchitecture
import Foundation
import AuthInterface
import Testing
import Web
@testable import Auth

struct SignUpFeatureTests {
  @Test @MainActor func legalDetailOpensWebAndKeepsDraftAfterClose() async {
    var state = SignUpFeature.State(legalBaseURL: URL(string: "https://example.com/api/v1/legal/"))
    state.nickname = "테스터"
    state.acceptedServiceTerms = true
    state.pushOptIn = true
    let store = TestStore(initialState: state) { SignUpFeature() }

    await store.send(.view(.legalDocumentTapped(.terms))) {
      $0.destination = .legalDocument(WebFeature.State(
        url: URL(string: "https://example.com/api/v1/legal/terms")!,
        title: "서비스 이용약관"
      ))
    }
    // Web을 닫으면 닉네임·약관 체크·알림 선택은 그대로다(TestStore가 나머지 상태 변화를 함께 확인한다).
    await store.send(.destination(.presented(.legalDocument(.view(.closeTapped)))))
    await store.receive(\.destination.presented.legalDocument.delegate.backToRoot) {
      $0.destination = nil
    }
  }

  @Test @MainActor func nicknameIsLimitedByTrimmedLength() async {
    let store = TestStore(initialState: SignUpFeature.State()) { SignUpFeature() }
    store.exhaustivity = .off

    // 앞뒤 공백은 길이에 세지 않고, 공백을 뺀 길이가 12자를 넘을 때만 자른다.
    await store.send(.view(.nicknameChanged("  열두글자딱맞는닉네임이에 ")))
    #expect(store.state.nickname == "  열두글자딱맞는닉네임이에 ")
    await store.send(.view(.nicknameChanged("  열세글자가넘는아주긴닉네임")))
    #expect(store.state.nickname == "열세글자가넘는아주긴닉네")
  }

  @Test @MainActor func legalDetailTapWithoutBaseURLDoesNothing() async {
    let store = TestStore(initialState: SignUpFeature.State()) { SignUpFeature() }

    await store.send(.view(.legalDocumentTapped(.privacy)))
  }

  @Test func submitNeedsCurrentConsentNicknameAndIdleFlow() {
    var state = SignUpFeature.State(legalBaseURL: URL(string: "https://example.com/api/v1/legal/"))
    state.currentTermsVersion = "2026-10"
    state.nickname = "테스터"
    state.acceptedServiceTerms = true
    state.acceptedPrivacyTerms = true
    state.termsDraftVersion = "2026-10"
    #expect(state.canSubmit)

    state.isSubmitting = true
    #expect(!state.canSubmit)
    state.isSubmitting = false
    state.termsUpdateExhausted = true
    #expect(!state.canSubmit)
    state.termsUpdateExhausted = false
    state.nickname = "  "
    #expect(!state.canSubmit)
    state.nickname = "테스터"
    state.currentTermsVersion = "2026-11"
    #expect(!state.canSubmit)

    var withoutLegal = SignUpFeature.State()
    withoutLegal.currentTermsVersion = "2026-10"
    withoutLegal.nickname = "테스터"
    withoutLegal.acceptedServiceTerms = true
    withoutLegal.acceptedPrivacyTerms = true
    withoutLegal.termsDraftVersion = "2026-10"
    #expect(!withoutLegal.canSubmit)
  }

  @Test @MainActor func submitSendsTrimmedNicknameWithValidity() async {
    var state = submittableState(nickname: "  테스터 ")
    state.pushOptIn = true
    let store = TestStore(initialState: state) { SignUpFeature() }

    await store.send(.view(.submitTapped))
    await store.receive(.delegate(.submitRequested(SignUpSubmission(
      nickname: "테스터", pushOptIn: true, isNicknameValid: true
    ))))
  }

  @Test @MainActor func nicknameOverTwelveCharactersIsInvalid() async {
    let nickname = String(repeating: "가", count: 13)
    let store = TestStore(initialState: submittableState(nickname: nickname)) { SignUpFeature() }

    await store.send(.view(.submitTapped))
    await store.receive(.delegate(.submitRequested(SignUpSubmission(
      nickname: nickname,
      pushOptIn: false,
      isNicknameValid: false
    ))))
  }

  @Test @MainActor func submitTapWithoutSubmittableStateDoesNothing() async {
    // 빈 닉네임이나 제출 중에는 제출 요청을 보내지 않는다.
    let blank = TestStore(initialState: submittableState(nickname: "   ")) { SignUpFeature() }
    await blank.send(.view(.submitTapped))

    var submitting = submittableState(nickname: "테스터")
    submitting.isSubmitting = true
    let busy = TestStore(initialState: submitting) { SignUpFeature() }
    await busy.send(.view(.submitTapped))
  }

  @Test @MainActor func flowChangedUpdatesParentFlowValues() async {
    let base = URL(string: "https://example.com/api/v1/legal/")
    let store = TestStore(initialState: SignUpFeature.State()) { SignUpFeature() }

    await store.send(.view(.flowChanged(
      isSubmitting: true,
      message: "약관이 다시 변경됐어요. 나중에 다시 시도해 주세요.",
      termsUpdateExhausted: true,
      legalBaseURL: base
    ))) {
      $0.isSubmitting = true
      $0.message = "약관이 다시 변경됐어요. 나중에 다시 시도해 주세요."
      $0.termsUpdateExhausted = true
      $0.legalBaseURL = base
    }
  }

  @Test @MainActor func sheetClosedClosesLegalDetail() async {
    let store = TestStore(initialState: SignUpFeature.State(legalBaseURL: URL(string: "https://example.com/api/v1/legal/"))) {
      SignUpFeature()
    }

    await store.send(.view(.legalDocumentTapped(.terms))) {
      $0.destination = .legalDocument(WebFeature.State(
        url: URL(string: "https://example.com/api/v1/legal/terms")!,
        title: "서비스 이용약관"
      ))
    }
    await store.send(.view(.sheetClosed)) {
      $0.destination = nil
    }
  }

  @Test @MainActor func legalDetailDismissKeepsDraft() async {
    var state = SignUpFeature.State(legalBaseURL: URL(string: "https://example.com/api/v1/legal/"))
    state.nickname = "테스터"
    state.acceptedPrivacyTerms = true
    let store = TestStore(initialState: state) { SignUpFeature() }

    await store.send(.view(.legalDocumentTapped(.privacy))) {
      $0.destination = .legalDocument(WebFeature.State(
        url: URL(string: "https://example.com/api/v1/legal/privacy")!,
        title: "개인정보 수집 · 이용"
      ))
    }
    // 끌어 내리는 등 표시 쪽에서 닫으면 `.dismiss`가 오고 초안은 그대로다.
    await store.send(.destination(.dismiss)) {
      $0.destination = nil
    }
  }

  @Test @MainActor func closeTappedRequestsClose() async {
    let store = TestStore(initialState: SignUpFeature.State()) { SignUpFeature() }

    await store.send(.view(.closeTapped))
    await store.receive(.delegate(.closeRequested))
  }

  @Test @MainActor func firstEditRecordsCurrentAccountAndTermsVersion() async {
    var state = SignUpFeature.State()
    state.currentUserID = "user-a"
    state.currentTermsVersion = "2026-10"
    let store = TestStore(initialState: state) { SignUpFeature() }

    await store.send(.view(.serviceTermsChanged(true))) {
      $0.acceptedServiceTerms = true
      $0.termsDraftVersion = "2026-10"
      $0.draftOwnerID = "user-a"
    }
    #expect(!store.state.acceptedTerms)
    #expect(store.state.consentedVersion == nil)

    await store.send(.view(.privacyTermsChanged(true))) {
      $0.acceptedPrivacyTerms = true
    }
    #expect(store.state.acceptedTerms)
    #expect(store.state.consentedVersion == "2026-10")

    await store.send(.view(.serviceTermsChanged(false))) {
      $0.acceptedServiceTerms = false
    }
    await store.send(.view(.privacyTermsChanged(false))) {
      $0.acceptedPrivacyTerms = false
      $0.termsDraftVersion = nil
    }
  }

  @Test func applyFillsServerNicknameOnlyWhenNotEdited() {
    var fresh = SignUpFeature.State()
    fresh.apply(profileUserID: "user-a", serverNickname: "서버 닉네임", termsVersion: "2026-10")
    #expect(fresh.nickname == "서버 닉네임")
    #expect(fresh.draftOwnerID == "user-a")

    var edited = SignUpFeature.State()
    edited.nicknameEdited = true
    edited.apply(profileUserID: "user-a", serverNickname: "서버 닉네임", termsVersion: "2026-10")
    #expect(edited.nickname.isEmpty)
  }

  @Test func applyClearsRequiredTermsWhenVersionChanges() {
    var state = SignUpFeature.State()
    state.nickname = "작성 중"
    state.acceptedServiceTerms = true
    state.acceptedPrivacyTerms = true
    state.termsDraftVersion = "2026-10"

    state.apply(profileUserID: "user-a", serverNickname: nil, termsVersion: "2026-11")
    #expect(!state.acceptedServiceTerms && !state.acceptedPrivacyTerms)
    #expect(state.termsDraftVersion == nil)
    #expect(state.nickname == "작성 중")
  }

  @Test func dismissalKeepsNicknamePushAndOwner() {
    var state = SignUpFeature.State()
    state.nickname = "작성 중"
    state.pushOptIn = true
    state.draftOwnerID = "user-a"
    state.acceptedServiceTerms = true
    state.termsDraftVersion = "2026-10"

    state.resetForDismissal()
    #expect(state.nickname == "작성 중")
    #expect(state.pushOptIn)
    #expect(state.draftOwnerID == "user-a")
    #expect(!state.acceptedServiceTerms)
    #expect(state.termsDraftVersion == nil)
  }

  @Test func reconcileDropsDraftFromAnotherAccount() {
    var state = SignUpFeature.State()
    state.nickname = "A의 초안"
    state.draftOwnerID = "user-a"

    let keptOwnDraft = !state.reconcile(userID: "user-a")
    #expect(keptOwnDraft)
    #expect(state.nickname == "A의 초안")
    let droppedOtherDraft = state.reconcile(userID: "user-b")
    #expect(droppedOtherDraft)
    #expect(state.nickname.isEmpty)
    #expect(state.draftOwnerID == nil)
  }

  private func submittableState(nickname: String) -> SignUpFeature.State {
    var state = SignUpFeature.State(legalBaseURL: URL(string: "https://example.com/api/v1/legal/"))
    state.currentTermsVersion = "2026-10"
    state.nickname = nickname
    state.acceptedServiceTerms = true
    state.acceptedPrivacyTerms = true
    state.termsDraftVersion = "2026-10"
    return state
  }
}
