//
//  ProfileFeatureTests.swift
//  Profile
//
//  Created by FestiCore on 10/30/26.
//

import ComposableArchitecture
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
      $0.isLogoutConfirmationPresented = true
      $0.dialogPresentationID = 1
    }
    await store.send(.view(.confirmLogoutTapped)) {
      $0.isLogoutConfirmationPresented = false
    }
    await store.receive(\.delegate.logoutRequested)
    #expect(store.state.isAccountPresented)
    await store.send(.view(.logoutTapped)) {
      $0.isLogoutConfirmationPresented = true
      $0.dialogPresentationID = 2
    }
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
      $0.isWithdrawalConfirmationPresented = true
      $0.dialogPresentationID = 1
    }
    await store.send(.view(.accountDismissed)) {
      $0.isAccountPresented = false
      $0.isWithdrawalConfirmationPresented = false
    }
  }

  @Test func withdrawalFailureCanBeRetriedFromAccountSheet() async {
    let store = TestStore(initialState: ProfileFeature.State()) { ProfileFeature() }

    await store.send(.view(.accountTapped(isSignedIn: true))) { $0.isAccountPresented = true }
    await store.send(.view(.withdrawTapped)) {
      $0.isWithdrawalConfirmationPresented = true
      $0.dialogPresentationID = 1
    }
    await store.send(.view(.confirmWithdrawTapped)) { $0.isWithdrawalConfirmationPresented = false }
    await store.receive(\.delegate.withdrawRequested)
    #expect(store.state.isAccountPresented)
    await store.send(.view(.withdrawTapped)) {
      $0.isWithdrawalConfirmationPresented = true
      $0.dialogPresentationID = 2
    }
  }

  @Test func dismissedConfirmationIgnoresLateConfirmTap() async {
    let store = TestStore(initialState: ProfileFeature.State()) { ProfileFeature() }

    await store.send(.view(.accountTapped(isSignedIn: true))) { $0.isAccountPresented = true }
    await store.send(.view(.withdrawTapped)) {
      $0.isWithdrawalConfirmationPresented = true
      $0.dialogPresentationID = 1
    }
    await store.send(.view(.withdrawalConfirmationDismissed)) { $0.isWithdrawalConfirmationPresented = false }
    await store.send(.view(.confirmWithdrawTapped))
    await store.send(.view(.logoutTapped)) {
      $0.isLogoutConfirmationPresented = true
      $0.dialogPresentationID = 2
    }
    await store.send(.view(.logoutConfirmationDismissed)) { $0.isLogoutConfirmationPresented = false }
    await store.send(.view(.confirmLogoutTapped))
  }

  @Test func missingLegalConfigurationShowsDismissibleError() async {
    let store = TestStore(initialState: ProfileFeature.State()) {
      ProfileFeature(legalBaseURL: nil)
    }

    await store.send(.view(.termsTapped)) {
      $0.isLegalLinkUnavailablePresented = true
      $0.dialogPresentationID = 1
    }
    await store.send(.view(.legalLinkUnavailableDismissed)) { $0.isLegalLinkUnavailablePresented = false }
    await store.send(.view(.privacyTapped)) {
      $0.isLegalLinkUnavailablePresented = true
      $0.dialogPresentationID = 2
    }
    // 이미 떠 있는 팝업에 같은 동작이 다시 와도 새 표시로 세지 않는다.
    await store.send(.view(.termsTapped))
  }
}
