import ComposableArchitecture
@testable import Festival
import FestivalDomainInterface
import Foundation
import Testing

@MainActor
struct FestivalAccountChangeTests {
  @Test func accountChangeWhileLiveBoardHiddenClearsAccountDataWithoutLoading() async {
    let store = TestStore(initialState: {
      var state = FestivalFeature.State(selectedFestivalID: "festival")
      state.liveBoard = previousBoard
      state.liveBoardUnavailable = true
      state.hasSession = true
      state.sessionUserID = "user-a"
      state.bookedUserID = "user-a"
      state.bookedFestivalIDs = ["festival"]
      return state
    }()) { FestivalFeature() }

    await store.send(.accountChanged) {
      $0.liveBoard = nil
      $0.liveBoardUnavailable = false
      $0.bookedUserID = nil
      $0.bookedFestivalIDs = []
      $0.hasSession = false
      $0.sessionUserID = nil
      $0.accountGeneration = 1
    }
  }

  @Test func accountChangeWhileLiveBoardVisibleDropsPreviousAccountResponseAndReloads() async {
    let current = FestivalLiveBoardSnapshot(festivalID: "festival", activeFlags: [], followedFlags: [], crew: nil)
    let clock = TestClock()
    let signedIn = LockIsolated(true)
    let started = LockIsolated(false)
    let receivedAt = Date(timeIntervalSince1970: 1_000)
    let store = TestStore(initialState: {
      var state = FestivalFeature.State(selectedFestivalID: "festival")
      state.liveBoard = previousBoard
      state.hasSession = true
      state.sessionUserID = "user-a"
      return state
    }()) { FestivalFeature() } withDependencies: {
      $0.continuousClock = clock
      $0.date = .constant(receivedAt)
      $0.festivalLiveBoardService = AccountLiveBoardService { _ in
        guard signedIn.value else { return current }
        started.setValue(true)
        try await clock.sleep(for: .seconds(1))
        return previousBoard
      }
    }

    await store.send(.view(.liveBoardOnAppear)) {
      $0.isLiveBoardVisible = true
      $0.myScheduleRequestID = 1
    }
    await store.receive(\.inner.myScheduleLoaded) {
      $0.mySchedule = .init(festivalID: "festival", setIDs: [])
    }
    while !started.value {
      await Task.yield()
    }
    signedIn.setValue(false)
    await store.send(.accountChanged) {
      $0.liveBoard = nil
      $0.mySchedule = nil
      $0.hasSession = false
      $0.sessionUserID = nil
      $0.accountGeneration = 1
    }
    await store.receive(\.inner.liveBoardLoaded) {
      $0.liveBoard = current
      $0.liveBoardReceivedAt = receivedAt
    }
    await clock.advance(by: .seconds(1))
    #expect(store.state.liveBoard == current)
    await store.send(.view(.liveBoardOnDisappear)) {
      $0.isLiveBoardVisible = false
      $0.myScheduleRequestID = 2
    }
  }
}

private let previousBoard = FestivalLiveBoardSnapshot(
  festivalID: "festival",
  activeFlags: [],
  followedFlags: [.init(id: "followed", name: "이전 계정 깃발", status: "active", zoneID: "A", activity: nil, thumbnailURL: nil)],
  crew: .init(id: "crew", name: "이전 계정 크루", members: [])
)

private struct AccountLiveBoardService: FestivalLiveBoardService {
  let handler: @Sendable (String) async throws -> FestivalLiveBoardSnapshot

  func refresh(for festivalID: String) async throws -> FestivalLiveBoardSnapshot {
    try await handler(festivalID)
  }
}
