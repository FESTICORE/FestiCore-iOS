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

  @Test func failedRefreshKeepsExistingFlagsForOfflineDisplay() async {
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
    await store.receive(\.failed) { $0.viewState = .failed }
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
}

private struct StubLiveBoardService: FestivalLiveBoardService {
  let result: Result<FestivalLiveBoardSnapshot, FestivalLiveBoardError>

  func refresh(for festivalID: String) async throws -> FestivalLiveBoardSnapshot {
    try result.get()
  }
}
