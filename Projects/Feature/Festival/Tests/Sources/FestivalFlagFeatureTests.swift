import ComposableArchitecture
import FestivalDomainInterface
import Testing
@testable import Festival

@MainActor
struct FestivalFlagFeatureTests {
  @Test func selectedFestivalLoadsItsFlags() async {
    let snapshot = FestivalLiveBoardSnapshot(
      festivalID: "festival-a",
      activeFlags: [.init(id: "flag", name: "깃발", status: "active", zoneID: "A", activity: nil, thumbnailURL: nil)],
      followedFlags: [], crew: nil
    )
    let store = TestStore(initialState: FestivalFlagFeature.State(festivalID: "festival-a")) {
      FestivalFlagFeature()
    } withDependencies: {
      $0.festivalLiveBoardService = StubLiveBoardService(result: .success(snapshot))
    }

    await store.send(.appeared) {
      $0.isVisible = true
      $0.viewState = .loading
    }
    await store.receive(\.loaded) {
      $0.snapshot = snapshot
      $0.viewState = .loaded
    }
  }

  @Test func festivalChangeClearsPreviousFlagsBeforeLoadingNewFestival() async {
    let old = FestivalLiveBoardSnapshot(festivalID: "old", activeFlags: [], followedFlags: [], crew: nil)
    let store = TestStore(initialState: {
      var state = FestivalFlagFeature.State(festivalID: "old")
      state.snapshot = old
      state.viewState = .loaded
      return state
    }()) { FestivalFlagFeature() }

    await store.send(.festivalChanged("new")) {
      $0.festivalID = "new"
      $0.snapshot = nil
      $0.viewState = .idle
    }
    await store.send(.loaded("old", old))
  }

  @Test func invalidResponseKeepsExistingFlagsForRecoveryDisplay() async {
    let cached = FestivalLiveBoardSnapshot(festivalID: "festival", activeFlags: [], followedFlags: [], crew: nil)
    let store = TestStore(initialState: {
      var state = FestivalFlagFeature.State(festivalID: "festival")
      state.isVisible = true
      state.snapshot = cached
      state.viewState = .loaded
      return state
    }()) { FestivalFlagFeature() } withDependencies: {
      $0.festivalLiveBoardService = StubLiveBoardService(result: .failure(.invalidResponse))
    }

    await store.send(.refresh) { $0.viewState = .loading }
    await store.receive(\.failed) { $0.viewState = .invalidResponse }
    #expect(store.state.snapshot == cached)
  }

  @Test func missingDeviceRegistrationShowsRecoveryState() async {
    let store = TestStore(initialState: FestivalFlagFeature.State(festivalID: "festival")) {
      FestivalFlagFeature()
    } withDependencies: {
      $0.festivalLiveBoardService = StubLiveBoardService(result: .failure(.deviceNotRegistered))
    }

    await store.send(.appeared) {
      $0.isVisible = true
      $0.viewState = .loading
    }
    await store.receive(\.failed) { $0.viewState = .deviceNotRegistered }
  }

  @Test(arguments: [FestivalLiveBoardError.invalidFestivalID, .invalidResponse])
  func contractErrorsAreNotShownAsNetworkFailures(error: FestivalLiveBoardError) async {
    let store = TestStore(initialState: FestivalFlagFeature.State(festivalID: "festival")) {
      FestivalFlagFeature()
    } withDependencies: {
      $0.festivalLiveBoardService = StubLiveBoardService(result: .failure(error))
    }

    await store.send(.appeared) {
      $0.isVisible = true
      $0.viewState = .loading
    }
    await store.receive(\.failed) {
      $0.viewState = error == .invalidFestivalID ? .invalidFestivalID : .invalidResponse
    }
  }

  @Test func accountChangeWhileHiddenClearsFlagsWithoutLoading() async {
    let previous = FestivalLiveBoardSnapshot(festivalID: "festival", activeFlags: [], followedFlags: [], crew: nil)
    let store = TestStore(initialState: {
      var state = FestivalFlagFeature.State(festivalID: "festival")
      state.snapshot = previous
      state.viewState = .loaded
      return state
    }()) { FestivalFlagFeature() }

    await store.send(.accountChanged) {
      $0.snapshot = nil
      $0.viewState = .idle
    }
  }

  @Test func accountChangeWhileVisibleDropsPreviousAccountResponseAndReloads() async {
    let previous = FestivalLiveBoardSnapshot(
      festivalID: "festival",
      activeFlags: [],
      followedFlags: [.init(id: "followed", name: "이전 계정 깃발", status: "active", zoneID: "A", activity: nil, thumbnailURL: nil)],
      crew: nil
    )
    let current = FestivalLiveBoardSnapshot(festivalID: "festival", activeFlags: [], followedFlags: [], crew: nil)
    let clock = TestClock()
    let signedIn = LockIsolated(true)
    let started = LockIsolated(false)
    let store = TestStore(initialState: {
      var state = FestivalFlagFeature.State(festivalID: "festival")
      state.isVisible = true
      return state
    }()) { FestivalFlagFeature() } withDependencies: {
      $0.festivalLiveBoardService = ClosureLiveBoardService { _ in
        guard signedIn.value else { return current }
        started.setValue(true)
        try await clock.sleep(for: .seconds(1))
        return previous
      }
    }

    await store.send(.refresh) { $0.viewState = .loading }
    while !started.value { await Task.yield() }
    signedIn.setValue(false)
    await store.send(.accountChanged)
    await store.receive(\.loaded) {
      $0.snapshot = current
      $0.viewState = .loaded
    }
    await clock.run()
    #expect(store.state.snapshot == current)
  }
}

private struct StubLiveBoardService: FestivalLiveBoardService {
  let result: Result<FestivalLiveBoardSnapshot, FestivalLiveBoardError>

  func refresh(for festivalID: String) async throws -> FestivalLiveBoardSnapshot {
    try result.get()
  }
}

private struct ClosureLiveBoardService: FestivalLiveBoardService {
  let handler: @Sendable (String) async throws -> FestivalLiveBoardSnapshot

  func refresh(for festivalID: String) async throws -> FestivalLiveBoardSnapshot {
    try await handler(festivalID)
  }
}
