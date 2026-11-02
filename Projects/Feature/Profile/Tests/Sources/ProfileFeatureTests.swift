//
//  ProfileFeatureTests.swift
//  Profile
//
//  Created by FestiCore on 10/30/26.
//

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
