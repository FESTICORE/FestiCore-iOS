//
//  ProfileFeatureTests.swift
//  Profile
//
//  Created by FestiCore on 10/30/26.
//

import AuthDomainInterface
import ComposableArchitecture
import FestiCoreSharedUI
import FestivalDomainInterface
import Foundation
import Testing
@testable import Profile

@MainActor
struct ProfileFeatureTests {
  @Test func appearLoadsLocalPacksThenRefreshesUpdates() async {
    let local = [FestivalReceivedPack(id: "fst_a", name: "원더리벳 2026", packVersion: 12, latestPackVersion: 12)]
    let refreshed = [FestivalReceivedPack(id: "fst_a", name: "원더리벳 2026", packVersion: 12, latestPackVersion: 13)]
    let store = TestStore(initialState: ProfileFeature.State()) {
      ProfileFeature()
    } withDependencies: {
      $0.festivalReceivedPackUseCase = MockFestivalReceivedPackUseCase(
        receivedPacks: { local },
        refreshReceivedPacks: { refreshed }
      )
    }

    await store.send(.view(.onAppear)) { $0.packLoad = .loading }
    await store.receive(\.async.fetchPacks)
    await store.receive(\.inner.packsLoaded) {
      $0.packs = local
      $0.packLoad = .loaded
    }
    await store.receive(\.inner.packsRefreshed) { $0.packs = refreshed }
    #expect(store.state.packs.first?.hasUpdate == true)
  }

  @Test func refreshFailureKeepsLocalPacks() async {
    let local = [FestivalReceivedPack(id: "fst_a", name: "A", packVersion: 1)]
    let store = TestStore(initialState: ProfileFeature.State()) {
      ProfileFeature()
    } withDependencies: {
      $0.festivalReceivedPackUseCase = MockFestivalReceivedPackUseCase(
        receivedPacks: { local },
        refreshReceivedPacks: { throw URLError(.notConnectedToInternet) }
      )
    }

    await store.send(.view(.onAppear)) { $0.packLoad = .loading }
    await store.receive(\.async.fetchPacks)
    await store.receive(\.inner.packsLoaded) {
      $0.packs = local
      $0.packLoad = .loaded
    }
  }

  @Test func localPackFailureShowsRetry() async {
    let attempts = LockIsolated(0)
    let store = TestStore(initialState: ProfileFeature.State()) {
      ProfileFeature()
    } withDependencies: {
      $0.festivalReceivedPackUseCase = MockFestivalReceivedPackUseCase(
        receivedPacks: {
          attempts.withValue { $0 += 1 }
          if attempts.value == 1 { throw URLError(.cannotOpenFile) }
          return []
        },
        refreshReceivedPacks: { [] }
      )
    }

    await store.send(.view(.onAppear)) { $0.packLoad = .loading }
    await store.receive(\.async.fetchPacks)
    await store.receive(\.inner.packsFailed) { $0.packLoad = .failed }
    await store.send(.view(.packsRetryTapped)) { $0.packLoad = .loading }
    await store.receive(\.async.fetchPacks)
    await store.receive(\.inner.packsLoaded) { $0.packLoad = .loaded }
    await store.receive(\.inner.packsRefreshed)
  }

  @Test func reappearKeepsShownPacksWhileReloading() async {
    var state = ProfileFeature.State()
    state.packs = [FestivalReceivedPack(id: "fst_a", name: "A", packVersion: 1)]
    state.packLoad = .loaded
    let store = TestStore(initialState: state) {
      ProfileFeature()
    } withDependencies: {
      $0.festivalReceivedPackUseCase = MockFestivalReceivedPackUseCase(
        receivedPacks: { throw URLError(.cannotOpenFile) },
        refreshReceivedPacks: { [] }
      )
    }

    await store.send(.view(.onAppear))
    await store.receive(\.async.fetchPacks)
    await store.receive(\.inner.packsFailed)
  }

  @Test func guestAccountRequestsLogin() async {
    let store = TestStore(initialState: ProfileFeature.State()) { ProfileFeature() }

    await store.send(.view(.accountTapped))
    await store.receive(\.delegate.loginRequested)
  }

  @Test func packTapOpensPackDetailAndDeletionReloadsPacks() async {
    var state = ProfileFeature.State()
    state.packs = [FestivalReceivedPack(id: "fst_a", name: "원더리벳 2026", packVersion: 12)]
    state.packLoad = .loaded
    let store = TestStore(initialState: state) {
      ProfileFeature()
    } withDependencies: {
      $0.festivalReceivedPackUseCase = MockFestivalReceivedPackUseCase(
        receivedPacks: { [] },
        refreshReceivedPacks: { [] }
      )
    }

    await store.send(.view(.packTapped("fst_unknown")))
    await store.send(.view(.packTapped("fst_a"))) {
      $0.destination = .packDetail(.init(festivalID: "fst_a", title: "원더리벳 2026"))
    }
    await store.send(.destination(.presented(.packDetail(.delegate(.packDeleted))))) {
      $0.destination = nil
    }
    await store.receive(\.async.fetchPacks)
    await store.receive(\.inner.packsLoaded) { $0.packs = [] }
    await store.receive(\.inner.packsRefreshed)
  }

  @Test func accountTapOpensAccountScreenAndForwardsAccountChanges() async {
    let store = TestStore(initialState: signedInState()) { ProfileFeature() }

    await store.send(.view(.accountTapped)) {
      $0.destination = .account(.init(profile: nil))
    }
    await store.send(.view(.accountChanged(profile: nil, hasSession: true, isLoading: true, message: nil))) {
      $0.isLoading = true
    }
    await store.receive(\.destination.presented.account.view.accountChanged) {
      $0.destination = .account(.init(profile: nil, isLoading: true))
    }
  }

  @Test func losingSessionClosesAccountScreen() async {
    var state = signedInState()
    state.destination = .account(.init(profile: nil))
    let store = TestStore(initialState: state) { ProfileFeature() }

    await store.send(.view(.accountChanged(profile: nil, hasSession: false, isLoading: false, message: nil))) {
      $0.hasSession = false
      $0.destination = nil
    }
  }

  @Test func accountScreenRequestsAreForwardedToApp() async {
    let user = AuthUser(
      id: "user-a", provider: "apple", email: nil, nickname: "새이름", nicknameConfirmed: true,
      termsAcceptedAt: "2026-10-01", termsVersion: "2026-10", pushOptIn: false, profileImageURL: nil
    )
    var state = signedInState()
    state.destination = .account(.init(profile: nil))
    let store = TestStore(initialState: state) { ProfileFeature() }

    await store.send(.destination(.presented(.account(.delegate(.logoutRequested)))))
    await store.receive(\.delegate.logoutRequested)
    await store.send(.destination(.presented(.account(.delegate(.withdrawRequested)))))
    await store.receive(\.delegate.withdrawRequested)
    await store.send(.destination(.presented(.account(.delegate(.nicknameUpdated(user))))))
    await store.receive(\.delegate.profileUpdated)
    await store.send(.destination(.presented(.account(.delegate(.backRequested))))) {
      $0.destination = nil
    }
  }

  @Test func notificationsTapOpensNotificationSettings() async {
    let store = TestStore(initialState: ProfileFeature.State()) { ProfileFeature() }

    await store.send(.view(.notificationsTapped)) {
      $0.destination = .notifications(.init())
    }
    await store.send(.destination(.presented(.notifications(.delegate(.backRequested))))) {
      $0.destination = nil
    }
  }

  @Test func missingLegalConfigurationShowsDismissibleError() async {
    let store = TestStore(initialState: ProfileFeature.State()) {
      ProfileFeature(legalBaseURL: nil)
    }

    await store.send(.view(.termsTapped)) {
      $0.destination = .alert(.legalLinkUnavailable())
    }
    // 이미 떠 있는 팝업에 같은 동작이 다시 와도 새로 띄우지 않는다.
    await store.send(.view(.privacyTapped))
    await store.send(.destination(.presented(.alert(.confirmTapped)))) {
      $0.destination = nil
    }
  }

  private func signedInState() -> ProfileFeature.State {
    var state = ProfileFeature.State()
    state.hasSession = true
    return state
  }
}
