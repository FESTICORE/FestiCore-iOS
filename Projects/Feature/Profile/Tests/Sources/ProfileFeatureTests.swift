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

    await store.send(.view(.accountTapped(isSignedIn: false)))
    await store.receive(\.delegate.loginRequested)
  }

  @Test func signedInAccountRequiresConfirmationBeforeLogout() async {
    let store = TestStore(initialState: ProfileFeature.State()) { ProfileFeature() }

    await store.send(.view(.accountTapped(isSignedIn: true))) { $0.isAccountPresented = true }
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
    let store = TestStore(initialState: ProfileFeature.State()) { ProfileFeature() }

    await store.send(.view(.accountTapped(isSignedIn: true))) { $0.isAccountPresented = true }
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
    let store = TestStore(initialState: ProfileFeature.State()) { ProfileFeature() }

    await store.send(.view(.accountTapped(isSignedIn: true))) { $0.isAccountPresented = true }
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

  @Test func cancelOrDimDismissDoesNotRunAction() async {
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
}
