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
      $0.festivalFlagUseCase = stubFlagUseCase(result: .success(snapshot))
    }

    await store.send(.view(.appeared)) { $0.isVisible = true }
    await store.receive(\.async.load) { $0.viewState = .loading }
    await store.receive(\.inner.loaded) {
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

    await store.send(.inner(.festivalChanged("new"))) {
      $0.festivalID = "new"
      $0.snapshot = nil
      $0.viewState = .idle
      $0.generation = 1
    }
    await store.send(.inner(.loaded("old", generation: 0, old)))
    await store.send(.inner(.failed("old", generation: 0, .unavailable)))
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
      $0.festivalFlagUseCase = stubFlagUseCase(result: .failure(.invalidResponse))
    }

    await store.send(.view(.refresh))
    await store.receive(\.async.load) { $0.viewState = .loading }
    await store.receive(\.inner.failed) { $0.viewState = .invalidResponse }
    #expect(store.state.snapshot == cached)
  }

  @Test func missingDeviceRegistrationShowsRecoveryState() async {
    let store = TestStore(initialState: FestivalFlagFeature.State(festivalID: "festival")) {
      FestivalFlagFeature()
    } withDependencies: {
      $0.festivalFlagUseCase = stubFlagUseCase(result: .failure(.deviceNotRegistered))
    }

    await store.send(.view(.appeared)) { $0.isVisible = true }
    await store.receive(\.async.load) { $0.viewState = .loading }
    await store.receive(\.inner.failed) { $0.viewState = .deviceNotRegistered }
  }

  @Test(arguments: [FestivalLiveBoardError.invalidFestivalID, .invalidResponse])
  func contractErrorsAreNotShownAsNetworkFailures(error: FestivalLiveBoardError) async {
    let store = TestStore(initialState: FestivalFlagFeature.State(festivalID: "festival")) {
      FestivalFlagFeature()
    } withDependencies: {
      $0.festivalFlagUseCase = stubFlagUseCase(result: .failure(error))
    }

    await store.send(.view(.appeared)) { $0.isVisible = true }
    await store.receive(\.async.load) { $0.viewState = .loading }
    await store.receive(\.inner.failed) {
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

    await store.send(.inner(.accountChanged)) {
      $0.snapshot = nil
      $0.viewState = .idle
      $0.generation = 1
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
      state.snapshot = previous
      state.viewState = .loaded
      return state
    }()) { FestivalFlagFeature() } withDependencies: {
      $0.festivalFlagUseCase = MockFestivalFlagUseCase(liveBoard: { _ in
        guard signedIn.value else { return current }
        started.setValue(true)
        try await clock.sleep(for: .seconds(1))
        return previous
      })
    }

    await store.send(.view(.refresh))
    await store.receive(\.async.load) { $0.viewState = .loading }
    while !started.value { await Task.yield() }
    signedIn.setValue(false)
    await store.send(.inner(.accountChanged)) {
      $0.snapshot = nil
      $0.viewState = .idle
      $0.generation = 1
    }
    await store.receive(\.async.load) { $0.viewState = .loading }
    await store.receive(\.inner.loaded) {
      $0.snapshot = current
      $0.viewState = .loaded
    }
    await store.send(.inner(.loaded("festival", generation: 0, previous)))
    await store.send(.inner(.failed("festival", generation: 0, .unavailable)))
    await clock.run()
    #expect(store.state.snapshot == current)
  }

  @Test func previousFestivalGenerationIsIgnoredAfterReturningToSameFestival() async {
    let previous = FestivalLiveBoardSnapshot(
      festivalID: "festival", activeFlags: [],
      followedFlags: [.init(id: "previous", name: "이전 깃발", status: "active", zoneID: nil, activity: nil, thumbnailURL: nil)],
      crew: nil
    )
    let current = FestivalLiveBoardSnapshot(festivalID: "festival", activeFlags: [], followedFlags: [], crew: nil)
    let store = TestStore(initialState: FestivalFlagFeature.State(festivalID: "festival")) {
      FestivalFlagFeature()
    } withDependencies: {
      $0.festivalFlagUseCase = stubFlagUseCase(result: .success(current))
    }

    await store.send(.inner(.festivalChanged("other"))) {
      $0.festivalID = "other"
      $0.generation = 1
    }
    await store.send(.inner(.festivalChanged("festival"))) {
      $0.festivalID = "festival"
      $0.generation = 2
    }
    await store.send(.view(.appeared)) { $0.isVisible = true }
    await store.receive(\.async.load) { $0.viewState = .loading }
    await store.receive(\.inner.loaded) {
      $0.snapshot = current
      $0.viewState = .loaded
    }
    await store.send(.inner(.loaded("festival", generation: 0, previous)))
    await store.send(.inner(.failed("festival", generation: 0, .unavailable)))
    #expect(store.state.snapshot == current)
  }
}

private func stubFlagUseCase(
  result: Result<FestivalLiveBoardSnapshot, FestivalLiveBoardError>
) -> MockFestivalFlagUseCase {
  MockFestivalFlagUseCase(liveBoard: { _ in try result.get() })
}
