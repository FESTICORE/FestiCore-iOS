import ComposableArchitecture
@testable import Festival
import FestivalDomainInterface
import Foundation
import Testing

@MainActor
struct FestivalFlagDirectoryTests {
  // MARK: - 표시 행

  @Test func activeSortFollowsFigmaOrderWithUnknownStatusBeforeScheduled() {
    let snapshot = board([
      flag("ended", status: "ended", count: 97),
      flag("scheduled", status: "scheduled", count: 213),
      flag("resting", status: "resting", count: 540),
      flag("unknown", status: "unknown", count: 300),
      flag("active-small", status: "active", count: 862),
      flag("active-big", status: "active", count: 1284),
    ])

    let rows = FestivalFlagDirectory.State().rows(in: snapshot, isFailed: false)

    #expect(rows.map(\.id) == ["active-big", "active-small", "resting", "unknown", "scheduled", "ended"])
    #expect(rows.map(\.status) == [.active, .active, .resting, nil, .scheduled, .endedToday])
  }

  @Test func followerAndRecentSortsKeepServerOrderForTies() {
    let early = Date(timeIntervalSince1970: 100)
    let late = Date(timeIntervalSince1970: 200)
    let snapshot = board([
      flag("a", count: 10, updatedAt: early),
      flag("b", count: 30),
      flag("c", count: 10, updatedAt: late),
      flag("d", count: 30, updatedAt: early),
    ])
    var state = FestivalFlagDirectory.State()

    state.sort = .followers
    #expect(state.rows(in: snapshot, isFailed: false).map(\.id) == ["b", "d", "a", "c"])

    state.sort = .recent
    #expect(state.rows(in: snapshot, isFailed: false).map(\.id) == ["c", "a", "d", "b"])
  }

  @Test func rowShowsTagsFollowersAndZoneNames() {
    let snapshot = board(
      [
        flag("live", tags: ["slam", "jump", "newbie"], count: 1284, zone: "zone_live", home: "zone_home"),
        flag("home", tags: ["sing"], home: "zone_home"),
        flag("nowhere", tags: ["slam"], zone: "zone_unknown"),
      ],
      followed: ["home"]
    )
    var state = FestivalFlagDirectory.State()
    state.zoneNames = ["zone_live": "리벳 스테이지 앞 왼쪽", "zone_home": "원더 스테이지 앞"]

    let rows = state.rows(in: snapshot, isFailed: false)

    #expect(rows.map(\.zone) == ["리벳 스테이지 앞 왼쪽", "원더 스테이지 앞", "위치 미정"])
    #expect(rows.first?.followersText == "팔로워 1,284")
    #expect(rows.first?.tags == ["슬램", "초보 환영"])
    #expect(rows.map(\.isFollowing) == [false, true, false])

    state.tag = .slam
    #expect(state.rows(in: snapshot, isFailed: false).map(\.id) == ["live", "nowhere"])
  }

  @Test func refreshFailureAndPendingRequestDisableFollow() {
    let snapshot = board([flag("a"), flag("b")])
    var state = FestivalFlagDirectory.State()
    state.pendingFollows["a"] = .some(nil)

    #expect(state.rows(in: snapshot, isFailed: false).map(\.isFollowEnabled) == [false, true])
    #expect(state.rows(in: snapshot, isFailed: true).map(\.isFollowEnabled) == [false, false])
  }

  @Test func offlineTextUsesLastConfirmationTime() {
    let now = Date(timeIntervalSince1970: 1000)
    #expect(FestivalFlagDirectory.offlineText(receivedAt: now.addingTimeInterval(-180), now: now) == "오프라인 · 3분 전 정보")
    #expect(FestivalFlagDirectory.offlineText(receivedAt: now.addingTimeInterval(-30), now: now) == "오프라인 · 방금 전 정보")
    #expect(FestivalFlagDirectory.offlineText(receivedAt: now.addingTimeInterval(60), now: now) == "오프라인 · 방금 전 정보")
    #expect(FestivalFlagDirectory.offlineText(receivedAt: nil, now: now) == "오프라인 · 방금 전 정보")
  }

  // MARK: - 팔로우

  @Test func followSuccessOverridesSnapshotAndIgnoresRepeatedTap() async {
    let clock = TestClock()
    let snapshot = board([flag("a", count: 10)])
    let store = TestStore(initialState: loadedState(snapshot)) {
      FestivalFlagFeature()
    } withDependencies: {
      $0.festivalFlagFollowService = SuspendedFollowService(clock: clock, followerCount: 11)
    }

    await store.send(.directory(.followTapped(id: "a", follow: true, baseCount: 10))) {
      $0.directory.pendingFollows["a"] = .some(10)
    }
    // 응답 전에 다시 누르면 요청을 보내지 않는다.
    await store.send(.directory(.followTapped(id: "a", follow: true, baseCount: 10)))
    await clock.advance(by: .seconds(60))
    await store.receive(\.directory.followResponse) {
      $0.directory.pendingFollows = [:]
      $0.directory.followOverrides["a"] = .init(isFollowing: true, followerCount: 11, baseCount: 10)
    }

    let row = store.state.directory.rows(in: snapshot, isFailed: false).first
    #expect(row?.isFollowing == true)
    #expect(row?.followersText == "팔로워 11")
  }

  @Test func loggedOutFollowAsksAppToShowLogin() async {
    let store = TestStore(initialState: loadedState(board([flag("a")]))) {
      FestivalFlagFeature()
    } withDependencies: {
      $0.festivalFlagFollowService = StubFollowService(result: .failure(.loginRequired))
    }

    await store.send(.directory(.followTapped(id: "a", follow: true, baseCount: nil))) {
      $0.directory.pendingFollows["a"] = .some(nil)
    }
    await store.receive(\.directory.followResponse) { $0.directory.pendingFollows = [:] }
    await store.receive(\.directory.delegate.loginRequested)
  }

  @Test func termsRequiredFollowRequestsConsentFlow() async {
    let store = TestStore(initialState: loadedState(board([flag("a")]))) {
      FestivalFlagFeature()
    } withDependencies: {
      $0.festivalFlagFollowService = StubFollowService(result: .failure(.termsRequired))
    }

    await store.send(.directory(.followTapped(id: "a", follow: true, baseCount: nil))) {
      $0.directory.pendingFollows["a"] = .some(nil)
    }
    await store.receive(\.directory.followResponse) { $0.directory.pendingFollows = [:] }
    await store.receive(\.directory.delegate.termsAcceptanceRequested)
  }

  @Test(arguments: [
    (FestivalFlagFollowError.limitReached, "팔로우는 100개까지 할 수 있어요"),
    (.unavailable, "팔로우를 바꾸지 못했어요. 잠시 후 다시 시도해 주세요"),
  ])
  func failureShowsToastForTwoSeconds(error: FestivalFlagFollowError, message: String) async {
    let clock = TestClock()
    let store = TestStore(initialState: loadedState(board([flag("a")]))) {
      FestivalFlagFeature()
    } withDependencies: {
      $0.festivalFlagFollowService = StubFollowService(result: .failure(error))
      $0.continuousClock = clock
    }

    await store.send(.directory(.followTapped(id: "a", follow: true, baseCount: nil))) {
      $0.directory.pendingFollows["a"] = .some(nil)
    }
    await store.receive(\.directory.followResponse) {
      $0.directory.pendingFollows = [:]
      $0.directory.toast = message
    }
    await clock.advance(by: .seconds(2))
    await store.receive(\.directory.toastExpired) { $0.directory.toast = nil }
  }

  // MARK: - 새 조회와 덮어쓰기 값

  @Test func followFinishedDuringLoadSurvivesThatLoadUntilLaterConfirmation() async {
    let before = board([flag("a", count: 10)])
    let followedButCached = board([flag("a", count: 10)], followed: ["a"])
    let fresh = board([flag("a", count: 12)], followed: ["a"])
    var initial = loadedState(before)
    initial.viewState = .loading
    let store = TestStore(initialState: initial) {
      FestivalFlagFeature()
    } withDependencies: {
      $0.festivalFlagFollowService = StubFollowService(result: .success(.init(flagID: "a", isFollowing: true, followerCount: 11)))
      $0.festivalLiveBoardService = SequenceLiveBoardService([followedButCached, fresh])
    }

    await store.send(.directory(.followTapped(id: "a", follow: true, baseCount: 10))) {
      $0.directory.pendingFollows["a"] = .some(10)
    }
    await store.receive(\.directory.followResponse) {
      $0.directory.pendingFollows = [:]
      $0.directory.followOverrides["a"] = .init(isFollowing: true, followerCount: 11, baseCount: 10, skipsNextLoad: true)
    }
    // 팔로우 전에 출발한 조회 결과는 성공값을 지우지 않는다.
    await store.send(.loaded("festival", generation: 0, before)) {
      $0.viewState = .loaded
      $0.directory.followOverrides["a"]?.skipsNextLoad = false
    }
    #expect(store.state.directory.rows(in: before, isFailed: false).first?.isFollowing == true)

    // 팔로우 뒤 조회: 팔로우 여부는 서버를 따르고, 공개 캐시가 그대로인 팔로워 수는 유지한다.
    await store.send(.refresh) { $0.viewState = .loading }
    await store.receive(\.loaded) {
      $0.snapshot = followedButCached
      $0.viewState = .loaded
      $0.directory.followOverrides["a"] = .init(isFollowing: nil, followerCount: 11, baseCount: 10)
    }
    #expect(store.state.directory.rows(in: followedButCached, isFailed: false).first?.followersText == "팔로워 11")

    await store.send(.refresh) { $0.viewState = .loading }
    await store.receive(\.loaded) {
      $0.snapshot = fresh
      $0.viewState = .loaded
      $0.directory.followOverrides = [:]
    }
  }

  @Test func rejectedLoadDoesNotClearFollowResult() async {
    var initial = loadedState(board([flag("a")]))
    initial.viewState = .loading
    initial.directory.followOverrides["a"] = .init(isFollowing: true, followerCount: 1, baseCount: 0)
    let store = TestStore(initialState: initial) { FestivalFlagFeature() }

    await store.send(.loaded("another-festival", generation: 0, board([flag("a")])))
  }

  @Test(arguments: [true, false])
  func staleRefreshKeepsFollowResultUntilSnapshotConfirmsIt(isFollowing: Bool) async {
    let stale = board([flag("a", count: 10)], followed: isFollowing ? [] : ["a"])
    let confirmed = board(
      [flag("a", count: isFollowing ? 11 : 9)],
      followed: isFollowing ? ["a"] : []
    )
    var initial = loadedState(stale)
    initial.directory.followOverrides["a"] = .init(
      isFollowing: isFollowing,
      followerCount: isFollowing ? 11 : 9,
      baseCount: 10
    )
    let store = TestStore(initialState: initial) {
      FestivalFlagFeature()
    } withDependencies: {
      $0.festivalLiveBoardService = SequenceLiveBoardService([stale, confirmed])
    }

    await store.send(.refresh) { $0.viewState = .loading }
    await store.receive(\.loaded) {
      $0.snapshot = stale
      $0.viewState = .loaded
    }
    #expect(store.state.directory.rows(in: stale, isFailed: false).first?.isFollowing == isFollowing)

    await store.send(.refresh) { $0.viewState = .loading }
    await store.receive(\.loaded) {
      $0.snapshot = confirmed
      $0.viewState = .loaded
      $0.directory.followOverrides = [:]
    }
    #expect(store.state.directory.rows(in: confirmed, isFailed: false).first?.isFollowing == isFollowing)
  }

  @Test func rapidFollowThenUnfollowKeepsFinalCountThroughIntermediateCache() async {
    let original = board([flag("a", count: 10)])
    let intermediate = board([flag("a", count: 11)])
    let confirmed = board([flag("a", count: 10)])
    let store = TestStore(initialState: loadedState(original)) {
      FestivalFlagFeature()
    } withDependencies: {
      $0.festivalFlagFollowService = ToggleFollowService()
      $0.festivalLiveBoardService = SequenceLiveBoardService([intermediate, confirmed])
    }

    await store.send(.directory(.followTapped(id: "a", follow: true, baseCount: 10))) {
      $0.directory.pendingFollows["a"] = .some(10)
    }
    await store.receive(\.directory.followResponse) {
      $0.directory.pendingFollows = [:]
      $0.directory.followOverrides["a"] = .init(isFollowing: true, followerCount: 11, baseCount: 10)
    }
    // 화면이 가진 원본 스냅샷은 여전히 10명이다.
    await store.send(.directory(.followTapped(id: "a", follow: false, baseCount: 10))) {
      $0.directory.pendingFollows["a"] = .some(11)
    }
    await store.receive(\.directory.followResponse) {
      $0.directory.pendingFollows = [:]
      $0.directory.followOverrides["a"] = .init(isFollowing: false, followerCount: 10, baseCount: 11)
    }

    await store.send(.refresh) { $0.viewState = .loading }
    await store.receive(\.loaded) {
      $0.snapshot = intermediate
      $0.viewState = .loaded
      $0.directory.followOverrides["a"] = .init(isFollowing: nil, followerCount: 10, baseCount: 11)
    }
    #expect(store.state.directory.rows(in: intermediate, isFailed: false).first?.followersText == "팔로워 10")

    await store.send(.refresh) { $0.viewState = .loading }
    await store.receive(\.loaded) {
      $0.snapshot = confirmed
      $0.viewState = .loaded
      $0.directory.followOverrides = [:]
    }
    #expect(store.state.directory.rows(in: confirmed, isFailed: false).first?.followersText == "팔로워 10")
  }

  @Test func leavingTabCancelsRequestButKeepsFollowResultUntilConfirmed() async {
    let clock = TestClock()
    let snapshot = board([flag("a"), flag("b")])
    var initial = loadedState(snapshot)
    initial.directory.followOverrides["a"] = .init(isFollowing: true, followerCount: 3, baseCount: 2)
    let store = TestStore(initialState: initial) {
      FestivalFlagFeature()
    } withDependencies: {
      $0.festivalFlagFollowService = SuspendedFollowService(clock: clock)
      $0.festivalLiveBoardService = StubLiveBoardService(result: .failure(.invalidResponse))
    }

    await store.send(.directory(.followTapped(id: "b", follow: true, baseCount: nil))) {
      $0.directory.pendingFollows["b"] = .some(nil)
    }
    await store.send(.disappeared) {
      $0.isVisible = false
      $0.directory.pendingFollows = [:]
    }
    await clock.run()

    // 다시 들어와 조회가 실패하면 이전 스냅샷과 함께 성공값을 계속 보인다.
    await store.send(.appeared) {
      $0.isVisible = true
      $0.viewState = .loading
    }
    await store.receive(\.failed) { $0.viewState = .invalidResponse }
    let row = store.state.directory.rows(in: snapshot, isFailed: true).first
    #expect(row?.isFollowing == true)
    #expect(row?.isFollowEnabled == false)
  }

  @Test func festivalAndAccountChangesDropFollowResults() async {
    var initial = loadedState(board([flag("a")]))
    initial.isVisible = false
    initial.directory.followOverrides["a"] = .init(isFollowing: true, followerCount: 3, baseCount: 2)
    initial.directory.toast = "팔로우를 바꾸지 못했어요. 잠시 후 다시 시도해 주세요"
    let store = TestStore(initialState: initial) { FestivalFlagFeature() }

    await store.send(.accountChanged) {
      $0.snapshot = nil
      $0.viewState = .idle
      $0.generation = 1
      $0.directory.followOverrides = [:]
      $0.directory.toast = nil
    }

    var other = loadedState(board([flag("a")]))
    other.isVisible = false
    other.directory.followOverrides["a"] = .init(isFollowing: false, followerCount: 1, baseCount: 2)
    let festivalStore = TestStore(initialState: other) { FestivalFlagFeature() }
    await festivalStore.send(.festivalChanged("another")) {
      $0.festivalID = "another"
      $0.snapshot = nil
      $0.viewState = .idle
      $0.generation = 1
      $0.directory.followOverrides = [:]
    }
  }

  // MARK: - 요청 제한

  @Test func rateLimitKeepsPreviousFlagsAndRetriesAfterWaiting() async {
    let clock = TestClock()
    let previous = board([flag("a")])
    let next = board([flag("a"), flag("b")])
    let store = TestStore(initialState: loadedState(previous)) {
      FestivalFlagFeature()
    } withDependencies: {
      $0.continuousClock = clock
      $0.festivalLiveBoardService = SequenceLiveBoardService(
        [nil, next], firstError: .rateLimited(retryAfter: 30)
      )
    }

    await store.send(.refresh) { $0.viewState = .loading }
    await clock.advance(by: .seconds(29))
    #expect(store.state.snapshot == previous)
    await clock.advance(by: .seconds(1))
    await store.receive(\.refresh)
    await store.receive(\.loaded) {
      $0.snapshot = next
      $0.viewState = .loaded
    }
  }
}

// MARK: - 도우미

private func flag(
  _ id: String,
  status: String = "active",
  tags: [String] = [],
  count: Int? = nil,
  zone: String? = nil,
  home: String? = nil,
  updatedAt: Date? = nil
) -> FestivalLiveBoardSnapshot.Flag {
  .init(
    id: id, name: id, status: status, zoneID: zone, activity: nil, thumbnailURL: nil,
    tags: tags, updatedAt: updatedAt, followerCount: count, homeZoneID: home
  )
}

private func board(_ flags: [FestivalLiveBoardSnapshot.Flag], followed: [String] = []) -> FestivalLiveBoardSnapshot {
  .init(
    festivalID: "festival", activeFlags: [], followedFlags: followed.map { flag($0) }, crew: nil,
    directoryFlags: flags
  )
}

private func loadedState(_ snapshot: FestivalLiveBoardSnapshot) -> FestivalFlagFeature.State {
  var state = FestivalFlagFeature.State(festivalID: "festival")
  state.snapshot = snapshot
  state.viewState = .loaded
  state.isVisible = true
  return state
}

private struct StubFollowService: FestivalFlagFollowService {
  let result: Result<FestivalFlagFollowResult, FestivalFlagFollowError>

  func setFollowing(_: Bool, flagID _: String) async throws(FestivalFlagFollowError) -> FestivalFlagFollowResult {
    try result.get()
  }
}

private struct ToggleFollowService: FestivalFlagFollowService {
  func setFollowing(_ following: Bool, flagID: String) async throws(FestivalFlagFollowError) -> FestivalFlagFollowResult {
    .init(flagID: flagID, isFollowing: following, followerCount: following ? 11 : 10)
  }
}

/// 시계를 60초 진행해야 끝나는 팔로우 요청
private struct SuspendedFollowService: FestivalFlagFollowService {
  let clock: TestClock<Duration>
  var followerCount = 1

  func setFollowing(_ following: Bool, flagID: String) async throws(FestivalFlagFollowError) -> FestivalFlagFollowResult {
    do {
      try await clock.sleep(for: .seconds(60))
    } catch {
      throw .unavailable
    }
    return .init(flagID: flagID, isFollowing: following, followerCount: followerCount)
  }
}

private struct StubLiveBoardService: FestivalLiveBoardService {
  let result: Result<FestivalLiveBoardSnapshot, FestivalLiveBoardError>

  func refresh(for _: String) async throws -> FestivalLiveBoardSnapshot {
    try result.get()
  }
}

/// 호출마다 다음 결과를 돌려준다. `firstError`가 있으면 첫 호출은 그 오류다.
private actor SequenceLiveBoardService: FestivalLiveBoardService {
  private var snapshots: [FestivalLiveBoardSnapshot?]
  private var firstError: FestivalLiveBoardError?

  init(_ snapshots: [FestivalLiveBoardSnapshot?], firstError: FestivalLiveBoardError? = nil) {
    self.snapshots = snapshots
    self.firstError = firstError
  }

  func refresh(for _: String) async throws -> FestivalLiveBoardSnapshot {
    if let error = firstError {
      firstError = nil
      snapshots.removeFirst()
      throw error
    }
    guard let next = snapshots.removeFirst() else { throw FestivalLiveBoardError.invalidResponse }
    return next
  }
}
