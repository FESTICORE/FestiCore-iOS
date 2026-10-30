//
//  ProfileFeatureTests.swift
//  Profile
//
//  Created by FestiCore on 10/30/26.
//

import ComposableArchitecture
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
    await store.send(.view(.logoutTapped)) { $0.isLogoutConfirmationPresented = true }
    await store.send(.view(.confirmLogoutTapped)) {
      $0.isLogoutConfirmationPresented = false
      $0.isAccountPresented = false
    }
    await store.receive(\.delegate.logoutRequested)
  }

  @Test func packTapPreservesSelectedIdentity() async {
    let store = TestStore(initialState: ProfileFeature.State()) { ProfileFeature() }

    await store.send(.view(.packTapped("pack-1")))
    await store.receive(\.delegate.packRequested)
  }

  @Test func dismissingAccountAlsoClosesPendingConfirmation() async {
    let store = TestStore(initialState: ProfileFeature.State()) { ProfileFeature() }

    await store.send(.view(.accountTapped(isSignedIn: true))) { $0.isAccountPresented = true }
    await store.send(.view(.withdrawTapped)) { $0.isWithdrawalConfirmationPresented = true }
    await store.send(.view(.accountDismissed)) {
      $0.isAccountPresented = false
      $0.isWithdrawalConfirmationPresented = false
    }
  }
}
