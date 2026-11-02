//
//  ProfileFeatureTests.swift
//  Profile
//
//  Created by FestiCore on 10/30/26.
//

import ComposableArchitecture
import FestiCoreSharedUI
import Foundation
import Testing
@testable import Profile

@MainActor
struct ProfileFeatureTests {
  @Test func guestAccountRequestsLogin() async {
    let store = TestStore(initialState: ProfileFeature.State()) { ProfileFeature() }

    await store.send(.view(.accountTapped))
    await store.receive(\.delegate.loginRequested)
  }

  @Test func losingSessionClosesAccountSheetAndConfirmation() async {
    var state = signedInState()
    state.isAccountPresented = true
    state.destination = .alert(.logout())
    state.confirmation = .logout
    let store = TestStore(initialState: state) { ProfileFeature() }

    await store.send(.view(.accountChanged(profile: nil, hasSession: false, isLoading: false, message: nil))) {
      $0.hasSession = false
    }
    await store.receive(\.view.accountDismissed) {
      $0.isAccountPresented = false
      $0.destination = nil
      $0.confirmation = nil
    }
  }

  @Test func accountChangeWhileSignedInKeepsSheetOpen() async {
    var state = signedInState()
    state.isAccountPresented = true
    let store = TestStore(initialState: state) { ProfileFeature() }

    await store.send(.view(.accountChanged(profile: nil, hasSession: true, isLoading: true, message: nil))) {
      $0.isLoading = true
    }
  }

  @Test func signedInAccountRequiresConfirmationBeforeLogout() async {
    let store = TestStore(initialState: signedInState()) { ProfileFeature() }

    await store.send(.view(.accountTapped)) { $0.isAccountPresented = true }
    await store.send(.view(.logoutTapped)) {
      $0.destination = .alert(.logout())
      $0.confirmation = .logout
    }
    await store.send(.destination(.presented(.alert(.confirmTapped)))) {
      $0.destination = nil
      $0.confirmation = nil
    }
    await store.receive(\.delegate.logoutRequested)
    #expect(store.state.isAccountPresented)
    await store.send(.view(.logoutTapped)) {
      $0.destination = .alert(.logout())
      $0.confirmation = .logout
    }
  }

  @Test func repeatedTapDoesNotPresentConfirmationAgain() async {
    let store = TestStore(initialState: ProfileFeature.State()) { ProfileFeature() }

    await store.send(.view(.withdrawTapped)) {
      $0.destination = .alert(.withdraw())
      $0.confirmation = .withdraw
    }
    let presentationID = store.state.destination?.alert?.presentationID
    await store.send(.view(.withdrawTapped))
    #expect(store.state.destination?.alert?.presentationID == presentationID)
  }

  @Test func packTapPreservesSelectedIdentity() async {
    let store = TestStore(initialState: ProfileFeature.State()) { ProfileFeature() }

    await store.send(.view(.packTapped("pack-1")))
    await store.receive(\.delegate.packRequested)
  }

  @Test func dismissingAccountAlsoClosesPendingConfirmation() async {
    let store = TestStore(initialState: signedInState()) { ProfileFeature() }

    await store.send(.view(.accountTapped)) { $0.isAccountPresented = true }
    await store.send(.view(.withdrawTapped)) {
      $0.destination = .alert(.withdraw())
      $0.confirmation = .withdraw
    }
    await store.send(.view(.accountDismissed)) {
      $0.isAccountPresented = false
      $0.destination = nil
      $0.confirmation = nil
    }
  }

  @Test func withdrawalFailureCanBeRetriedFromAccountSheet() async {
    let store = TestStore(initialState: signedInState()) { ProfileFeature() }

    await store.send(.view(.accountTapped)) { $0.isAccountPresented = true }
    await store.send(.view(.withdrawTapped)) {
      $0.destination = .alert(.withdraw())
      $0.confirmation = .withdraw
    }
    await store.send(.destination(.presented(.alert(.confirmTapped)))) {
      $0.destination = nil
      $0.confirmation = nil
    }
    await store.receive(\.delegate.withdrawRequested)
    #expect(store.state.isAccountPresented)
    await store.send(.view(.withdrawTapped)) {
      $0.destination = .alert(.withdraw())
      $0.confirmation = .withdraw
    }
  }

  @Test func cancelTapOrDimDismissClosesWithoutRunningAction() async {
    let store = TestStore(initialState: ProfileFeature.State()) { ProfileFeature() }

    await store.send(.view(.withdrawTapped)) {
      $0.destination = .alert(.withdraw())
      $0.confirmation = .withdraw
    }
    await store.send(.destination(.presented(.alert(.cancelTapped)))) {
      $0.destination = nil
      $0.confirmation = nil
    }
    await store.send(.view(.logoutTapped)) {
      $0.destination = .alert(.logout())
      $0.confirmation = .logout
    }
    // 딤을 탭하면 fcAlert가 바인딩을 비워 dismiss를 보낸다.
    await store.send(.destination(.dismiss)) {
      $0.destination = nil
      $0.confirmation = nil
    }
  }

  @Test func missingLegalConfigurationShowsDismissibleError() async {
    let store = TestStore(initialState: ProfileFeature.State()) {
      ProfileFeature(legalBaseURL: nil)
    }

    await store.send(.view(.termsTapped)) {
      $0.destination = .alert(.legalLinkUnavailable())
      $0.confirmation = .legalLinkUnavailable
    }
    // 이미 떠 있는 팝업에 같은 동작이 다시 와도 새로 띄우지 않는다.
    await store.send(.view(.privacyTapped))
    await store.send(.destination(.presented(.alert(.confirmTapped)))) {
      $0.destination = nil
      $0.confirmation = nil
    }
  }

  private func signedInState() -> ProfileFeature.State {
    var state = ProfileFeature.State()
    state.hasSession = true
    return state
  }
}
