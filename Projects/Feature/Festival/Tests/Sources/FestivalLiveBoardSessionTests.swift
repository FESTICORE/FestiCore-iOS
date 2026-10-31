import ComposableArchitecture
import FestivalDomainInterface
import Foundation
import Testing
@testable import Festival

@MainActor
struct FestivalLiveBoardSessionTests {
  @Test("미발행 축제는 공개 전 상태를 표시하고 발행 후 자동으로 보드를 보여준다")
  func unpublishedFestivalBecomesAvailableOnNextPoll() async {
    let clock = TestClock()
    let calls = LockIsolated(0)
    let receivedAt = Date(timeIntervalSince1970: 2_000)
    let store = TestStore(initialState: {
      var state = FestivalFeature.State(selectedFestivalID: "fst")
      state.liveBoard = previousAccountBoard
      state.liveBoardReceivedAt = Date(timeIntervalSince1970: 1_000)
      return state
    }()) { FestivalFeature() } withDependencies: {
      $0.continuousClock = clock
      $0.date = .constant(receivedAt)
      $0.festivalLiveBoardService = SessionLiveBoardService { _ in
        let attempt = calls.withValue { count in
          count += 1
          return count
        }
        if attempt == 1 { throw FestivalLiveBoardError.festivalNotFound }
        return emptyBoard
      }
    }

    await store.send(.view(.liveBoardOnAppear)) { $0.isLiveBoardVisible = true }
    await store.receive(\.inner.liveBoardUnpublished) {
      $0.liveBoard = nil
      $0.liveBoardUnpublished = true
      $0.liveBoardReceivedAt = nil
    }
    await clock.advance(by: .seconds(35))
    await store.receive(\.inner.liveBoardLoaded) {
      $0.liveBoard = emptyBoard
      $0.liveBoardUnpublished = false
      $0.liveBoardClockAnchorAt = receivedAt
      $0.liveBoardReceivedAt = receivedAt
    }
    #expect(calls.value == 2)
    #expect(!store.state.liveBoardUnavailable)
    await store.send(.view(.liveBoardOnDisappear)) {
      $0.isLiveBoardVisible = false
      $0.myScheduleRequestID = 1
    }
  }

  @Test("사용자 ID를 확인하지 못한 세션도 라이브 보드가 보이면 내 일정을 불러온다")
  func sessionWithoutUserIDLoadsMySchedule() async {
    let clock = TestClock()
    let fetched = LockIsolated<[String]>([])
    let store = TestStore(initialState: FestivalFeature.State(selectedFestivalID: "fst")) {
      FestivalFeature()
    } withDependencies: {
      $0.continuousClock = clock
      $0.festivalLiveBoardService = SessionLiveBoardService { _ in
        try await clock.sleep(for: .seconds(60))
        return emptyBoard
      }
      $0.festivalScheduleService = SessionScheduleService { festivalID in
        fetched.withValue { $0.append(festivalID) }
        return ["set_a"]
      }
    }

    await store.send(.sessionChanged(hasSession: true, userID: nil)) {
      $0.hasSession = true
      $0.accountGeneration = 1
    }
    await store.send(.view(.liveBoardOnAppear)) {
      $0.isLiveBoardVisible = true
      $0.myScheduleRequestID = 1
    }
    await store.receive(\.inner.myScheduleLoaded) {
      $0.mySchedule = .init(festivalID: "fst", setIDs: ["set_a"])
    }
    #expect(fetched.value == ["fst"])
    await store.send(.view(.liveBoardOnDisappear)) {
      $0.isLiveBoardVisible = false
      $0.mySchedule = nil
      $0.myScheduleRequestID = 2
    }
  }

  @Test("로그아웃 상태에서는 내 일정을 불러오지 않는다")
  func loggedOutDoesNotLoadMySchedule() async {
    let clock = TestClock()
    let fetched = LockIsolated(0)
    let store = TestStore(initialState: FestivalFeature.State(selectedFestivalID: "fst")) {
      FestivalFeature()
    } withDependencies: {
      $0.continuousClock = clock
      $0.festivalLiveBoardService = SessionLiveBoardService { _ in
        try await clock.sleep(for: .seconds(60))
        return emptyBoard
      }
      $0.festivalScheduleService = SessionScheduleService { _ in
        fetched.withValue { $0 += 1 }
        return []
      }
    }

    await store.send(.view(.liveBoardOnAppear)) { $0.isLiveBoardVisible = true }
    await store.send(.view(.liveBoardOnDisappear)) {
      $0.isLiveBoardVisible = false
      $0.myScheduleRequestID = 1
    }
    #expect(fetched.value == 0)
  }

  @Test("다른 축제·이전 요청·이전 세대·숨긴 뒤의 내 일정 응답은 버린다")
  func staleMyScheduleResponsesAreIgnored() async {
    let store = TestStore(initialState: {
      var state = FestivalFeature.State(selectedFestivalID: "B")
      state.myScheduleRequestID = 2
      state.accountGeneration = 1
      state.hasSession = true
      state.isLiveBoardVisible = true
      return state
    }()) { FestivalFeature() }

    await store.send(.inner(.myScheduleLoaded(festivalID: "A", requestID: 2, generation: 1, ["x"])))
    await store.send(.inner(.myScheduleLoaded(festivalID: "B", requestID: 1, generation: 1, ["x"])))
    await store.send(.inner(.myScheduleLoaded(festivalID: "B", requestID: 2, generation: 0, ["x"])))
    await store.send(.inner(.myScheduleLoaded(festivalID: "B", requestID: 2, generation: 1, ["x"]))) {
      $0.mySchedule = .init(festivalID: "B", setIDs: ["x"])
    }
    await store.send(.view(.liveBoardOnDisappear)) {
      $0.isLiveBoardVisible = false
      $0.mySchedule = nil
      $0.myScheduleRequestID = 3
    }
    await store.send(.inner(.myScheduleLoaded(festivalID: "B", requestID: 2, generation: 1, ["y"])))
    await store.send(.inner(.myScheduleLoaded(festivalID: "B", requestID: 3, generation: 1, ["y"])))
  }

  @Test("계정 변경·익명에서 로그인 전환 뒤 이전 세대의 라이브 보드 응답은 버린다")
  func previousGenerationLiveBoardResponsesAreDropped() async {
    let store = TestStore(initialState: {
      var state = FestivalFeature.State(selectedFestivalID: "fst")
      state.hasSession = true
      state.sessionUserID = "user-a"
      return state
    }()) { FestivalFeature() }

    await store.send(.accountChanged) {
      $0.hasSession = false
      $0.sessionUserID = nil
      $0.accountGeneration = 1
    }
    await store.send(.inner(.liveBoardLoaded("fst", generation: 0, previousAccountBoard)))
    await store.send(.inner(.liveBoardFailed("fst", generation: 0)))

    await store.send(.sessionChanged(hasSession: true, userID: "user-b")) {
      $0.hasSession = true
      $0.sessionUserID = "user-b"
      $0.accountGeneration = 2
    }
    await store.send(.inner(.liveBoardLoaded("fst", generation: 1, previousAccountBoard)))
  }

  @Test("같은 세션 값이 다시 와도 비우거나 다시 불러오지 않는다")
  func sameSessionIsIgnored() async {
    let store = TestStore(initialState: {
      var state = FestivalFeature.State(selectedFestivalID: "fst")
      state.hasSession = true
      state.sessionUserID = "user-a"
      state.liveBoard = emptyBoard
      state.isLiveBoardVisible = true
      return state
    }()) { FestivalFeature() }

    await store.send(.sessionChanged(hasSession: true, userID: "user-a"))
  }

  @Test("로그아웃 때 보이는 라이브 보드는 한 번만 다시 불러온다")
  func logoutReloadsVisibleBoardOnce() async {
    let clock = TestClock()
    let calls = LockIsolated(0)
    let receivedAt = Date(timeIntervalSince1970: 1_000)
    let store = TestStore(initialState: {
      var state = FestivalFeature.State(selectedFestivalID: "fst")
      state.hasSession = true
      state.sessionUserID = "user-a"
      state.liveBoard = previousAccountBoard
      state.isLiveBoardVisible = true
      return state
    }()) { FestivalFeature() } withDependencies: {
      $0.continuousClock = clock
      $0.date = .constant(receivedAt)
      $0.festivalLiveBoardService = SessionLiveBoardService { _ in
        calls.withValue { $0 += 1 }
        return emptyBoard
      }
    }

    await store.send(.accountChanged) {
      $0.liveBoard = nil
      $0.hasSession = false
      $0.sessionUserID = nil
      $0.accountGeneration = 1
    }
    await store.receive(\.inner.liveBoardLoaded) {
      $0.liveBoard = emptyBoard
      $0.liveBoardClockAnchorAt = receivedAt
      $0.liveBoardReceivedAt = receivedAt
    }
    // AppCoordinator의 세션 변화 감지가 같은 전환으로 보내는 값은 무시된다.
    await store.send(.sessionChanged(hasSession: false, userID: nil))
    #expect(calls.value == 1)
    await store.send(.view(.liveBoardOnDisappear)) {
      $0.isLiveBoardVisible = false
      $0.myScheduleRequestID = 1
    }
  }

  @Test("세션 해제가 먼저 와도 로그아웃 전환은 라이브 보드를 한 번만 다시 불러온다")
  func logoutReloadsOnceWhenSessionChangeArrivesFirst() async {
    let clock = TestClock()
    let calls = LockIsolated(0)
    let receivedAt = Date(timeIntervalSince1970: 1_000)
    let store = TestStore(initialState: {
      var state = FestivalFeature.State(selectedFestivalID: "fst")
      state.hasSession = true
      state.sessionUserID = "user-a"
      state.liveBoard = previousAccountBoard
      state.bookedUserID = "user-a"
      state.bookedFestivalIDs = ["fst"]
      state.isLiveBoardVisible = true
      return state
    }()) { FestivalFeature() } withDependencies: {
      $0.continuousClock = clock
      $0.date = .constant(receivedAt)
      $0.festivalLiveBoardService = SessionLiveBoardService { _ in
        calls.withValue { $0 += 1 }
        return emptyBoard
      }
    }

    await store.send(.sessionChanged(hasSession: false, userID: nil)) {
      $0.hasSession = false
      $0.sessionUserID = nil
      $0.accountGeneration = 1
      $0.liveBoard = nil
      $0.bookedUserID = nil
      $0.bookedFestivalIDs = []
    }
    await store.receive(\.inner.liveBoardLoaded) {
      $0.liveBoard = emptyBoard
      $0.liveBoardClockAnchorAt = receivedAt
      $0.liveBoardReceivedAt = receivedAt
    }
    await store.send(.accountChanged)
    #expect(calls.value == 1)
    await store.send(.view(.liveBoardOnDisappear)) {
      $0.isLiveBoardVisible = false
      $0.myScheduleRequestID = 1
    }
  }

  @Test("로그인 카드는 코디네이터에 로그인을 요청한다")
  func loginTapRequestsLogin() async {
    let store = TestStore(initialState: FestivalFeature.State()) { FestivalFeature() }

    await store.send(.view(.loginTapped))
    await store.receive(\.delegate.loginRequested)
  }

  @Test("예약 목록이 새 사용자 ID와 같으면 세션 변경에도 보존한다")
  func sessionChangePreservesAlreadyReloadedBookmarks() async {
    let store = TestStore(initialState: {
      var state = FestivalFeature.State(selectedFestivalID: "fst")
      state.bookedUserID = "user-b"
      state.bookedFestivalIDs = ["fst"]
      return state
    }()) { FestivalFeature() }

    await store.send(.sessionChanged(hasSession: true, userID: "user-b")) {
      $0.hasSession = true
      $0.sessionUserID = "user-b"
      $0.accountGeneration = 1
    }
    #expect(store.state.bookedFestivalIDs == ["fst"])
  }

  @Test("사용자가 바뀌면 이전 사용자 예약 목록을 비운다")
  func sessionChangeClearsDifferentUserBookmarks() async {
    let store = TestStore(initialState: {
      var state = FestivalFeature.State(selectedFestivalID: "fst")
      state.hasSession = true
      state.sessionUserID = "user-a"
      state.bookedUserID = "user-a"
      state.bookedFestivalIDs = ["fst"]
      return state
    }()) { FestivalFeature() }

    await store.send(.sessionChanged(hasSession: true, userID: "user-b")) {
      $0.bookedUserID = nil
      $0.bookedFestivalIDs = []
      $0.sessionUserID = "user-b"
      $0.accountGeneration = 1
    }
  }

  @Test("저장한 일정은 보이는 같은 축제의 라이브 보드에만 반영한다")
  func savedScheduleUpdatesVisibleBoardOnly() async {
    let store = TestStore(initialState: {
      var state = FestivalFeature.State(selectedFestivalID: "fst")
      state.hasSession = true
      state.isLiveBoardVisible = true
      state.myScheduleRequestID = 1
      return state
    }()) { FestivalFeature() }

    await store.send(.myScheduleSaved(festivalID: "other", setIDs: ["other"]))
    await store.send(.myScheduleSaved(festivalID: "fst", setIDs: ["set-a"])) {
      $0.myScheduleRequestID = 2
      $0.mySchedule = .init(festivalID: "fst", setIDs: ["set-a"])
    }
    await store.send(.inner(.myScheduleLoaded(festivalID: "fst", requestID: 1, generation: 0, ["stale"])))
    await store.send(.view(.liveBoardOnDisappear)) {
      $0.isLiveBoardVisible = false
      $0.mySchedule = nil
      $0.myScheduleRequestID = 3
    }
    await store.send(.myScheduleSaved(festivalID: "fst", setIDs: ["hidden"]))
  }

  @Test("304로 같은 서버 시각을 다시 받아도 시계 기준점은 유지한다")
  func cachedLiveBoardDoesNotResetClock() async {
    let serverAt = Date(timeIntervalSince1970: 1_000)
    let firstReceivedAt = Date(timeIntervalSince1970: 2_000)
    let revalidatedAt = firstReceivedAt.addingTimeInterval(35)
    let board = FestivalLiveBoardSnapshot(
      festivalID: "fst", activeFlags: [], followedFlags: [], crew: nil, serverAt: serverAt
    )
    let store = TestStore(initialState: {
      var state = FestivalFeature.State(selectedFestivalID: "fst")
      state.liveBoard = board
      state.liveBoardClockAnchorAt = firstReceivedAt
      state.liveBoardReceivedAt = firstReceivedAt
      return state
    }()) { FestivalFeature() } withDependencies: {
      $0.date = .constant(revalidatedAt)
    }

    await store.send(.inner(.liveBoardLoaded("fst", generation: 0, board))) {
      $0.liveBoardReceivedAt = revalidatedAt
    }
    #expect(store.state.liveBoardClockAnchorAt == firstReceivedAt)
    #expect(FestivalLiveBoardPresentation.serverNow(
      serverAt: board.serverAt,
      clockAnchorAt: store.state.liveBoardClockAnchorAt,
      deviceNow: revalidatedAt
    ) == serverAt.addingTimeInterval(35))
  }

  @Test("내 일정 조회 실패를 표시하고 다시 시도해 복구한다")
  func failedMyScheduleCanRetry() async {
    let clock = TestClock()
    let attempts = LockIsolated(0)
    let store = TestStore(initialState: {
      var state = FestivalFeature.State(selectedFestivalID: "fst")
      state.hasSession = true
      return state
    }()) { FestivalFeature() } withDependencies: {
      $0.continuousClock = clock
      $0.festivalLiveBoardService = SessionLiveBoardService { _ in
        try await clock.sleep(for: .seconds(60))
        return emptyBoard
      }
      $0.festivalScheduleService = SessionScheduleService { _ in
        let attempt = attempts.withValue { value in
          value += 1
          return value
        }
        if attempt == 1 { throw FestivalScheduleError.unavailable }
        return ["set_a"]
      }
    }

    await store.send(.view(.liveBoardOnAppear)) {
      $0.isLiveBoardVisible = true
      $0.myScheduleRequestID = 1
    }
    await store.receive(\.inner.myScheduleFailed) {
      $0.myScheduleUnavailable = true
    }
    await store.send(.view(.retryMySchedule)) {
      $0.myScheduleUnavailable = false
      $0.myScheduleRequestID = 2
    }
    await store.receive(\.inner.myScheduleLoaded) {
      $0.mySchedule = .init(festivalID: "fst", setIDs: ["set_a"])
    }
    #expect(attempts.value == 2)
    await store.send(.view(.liveBoardOnDisappear)) {
      $0.isLiveBoardVisible = false
      $0.mySchedule = nil
      $0.myScheduleRequestID = 3
    }
  }
}

private let emptyBoard = FestivalLiveBoardSnapshot(festivalID: "fst", activeFlags: [], followedFlags: [], crew: nil)

private let previousAccountBoard = FestivalLiveBoardSnapshot(
  festivalID: "fst",
  activeFlags: [],
  followedFlags: [.init(id: "followed", name: "이전 계정 깃발", status: "active", zoneID: nil, activity: nil, thumbnailURL: nil)],
  crew: .init(id: "crew", name: "이전 계정 크루", members: [])
)

private struct SessionLiveBoardService: FestivalLiveBoardService {
  let handler: @Sendable (String) async throws -> FestivalLiveBoardSnapshot

  func refresh(for festivalID: String) async throws -> FestivalLiveBoardSnapshot {
    try await handler(festivalID)
  }
}

private struct SessionScheduleService: FestivalScheduleService {
  let handler: @Sendable (String) async throws -> [String]

  func fetch(festivalID: String) async throws(FestivalScheduleError) -> FestivalSchedule {
    do {
      return FestivalSchedule(setIDs: try await handler(festivalID))
    } catch let error as FestivalScheduleError {
      throw error
    } catch {
      throw .unavailable
    }
  }

  func replace(festivalID _: String, setIDs: [String], clientAt _: Date) async throws(FestivalScheduleError) -> FestivalSchedule {
    FestivalSchedule(setIDs: setIDs)
  }
}
