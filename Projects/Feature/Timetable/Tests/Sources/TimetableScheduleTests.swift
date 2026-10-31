import ComposableArchitecture
import FestivalDomainInterface
import Foundation
import Testing
@testable import Timetable

@MainActor
struct TimetableScheduleTests {
  /// 샘플 첫날(2026-08-07 KST) 전날 정오. 모든 공연이 시작 전이다.
  private let beforeFestival = Date(timeIntervalSince1970: 1_786_028_400 - 12 * 60 * 60)

  @Test func festivalChangeLoadsScheduleOnceAndDropsUnknownIDs() async {
    let service = ScheduleServiceSpy(fetchResults: [.success(.init(setIDs: ["lime", "gone"]))])
    let store = makeStore(TimetableFeature.State.sample(), service: service)

    await store.send(.festivalChanged("fst")) {
      $0.festivalID = "fst"
      $0.mySetIDs = []
      $0.scheduleSync = .loading
      $0.loadRequestID = 1
    }
    await store.receive(\.scheduleLoaded) {
      $0.mySetIDs = ["lime"]
      $0.scheduleSync = .ready
    }
    #expect(service.fetchCount.value == 1)
  }

  @Test func appearingWhileLoadingDoesNotLoadAgain() async {
    var state = readyState()
    state.scheduleSync = .loading
    let service = ScheduleServiceSpy()
    let store = makeStore(state, service: service)

    await store.send(.timetableAppeared)
    #expect(service.fetchCount.value == 0)
  }

  @Test func togglingWhileLoadingIsIgnored() async {
    var state = readyState(selected: "lime")
    state.scheduleSync = .loading
    let store = makeStore(state, service: ScheduleServiceSpy())

    await store.send(.view(.setScheduleToggled))
  }

  @Test func toggleSavesLatestSnapshotAfterInFlightSave() async {
    var state = readyState(selected: "lime")
    state.isSaving = true
    state.lastClientAt = beforeFestival
    let service = ScheduleServiceSpy()
    let clock = TestClock()
    let store = makeStore(state, service: service, clock: clock)
    let inFlight = TimetableFeature.ScheduleSave(setIDs: [], clientAt: beforeFestival, generation: 0)

    await store.send(.view(.setScheduleToggled)) {
      $0.mySetIDs = ["lime"]
      $0.needsSave = true
      $0.isScheduleToastVisible = true
    }
    await store.send(.scheduleSaved(festivalID: "fst", inFlight, .success(.init(setIDs: [])))) {
      $0.needsSave = false
      $0.lastClientAt = self.beforeFestival.addingTimeInterval(0.001)
    }
    await store.receive(scheduleSaved(festivalID: "fst", setIDs: []))
    await store.receive(\.scheduleSaved) {
      $0.isSaving = false
    }
    await store.receive(scheduleSaved(festivalID: "fst", setIDs: ["lime"]))
    // 같은 시각에 이어진 저장도 서버 충돌을 피하도록 1ms 늦춘다.
    #expect(service.replaced.value == [.init(setIDs: ["lime"], clientAt: beforeFestival.addingTimeInterval(0.001), generation: 0)])
    await clock.advance(by: .seconds(2))
    await store.receive(\.scheduleToastExpired) {
      $0.isScheduleToastVisible = false
    }
  }

  @Test func staleSaveAdoptsServerScheduleAndDropsPendingChange() async {
    var state = readyState(mine: ["lime"])
    state.isSaving = true
    state.needsSave = true
    let service = ScheduleServiceSpy()
    let store = makeStore(state, service: service)
    let save = TimetableFeature.ScheduleSave(setIDs: [], clientAt: beforeFestival, generation: 0)

    await store.send(.scheduleSaved(festivalID: "fst", save, .failure(.stale(.init(setIDs: ["noise", "gone"]))))) {
      $0.isSaving = false
      $0.needsSave = false
      $0.mySetIDs = ["noise"]
    }
    await store.receive(scheduleSaved(festivalID: "fst", setIDs: ["noise"]))
    #expect(service.replaced.value.isEmpty)
  }

  @Test func unauthorizedLoadKeepsScheduleOnDevice() async {
    let service = ScheduleServiceSpy(fetchResults: [.failure(.unauthorized)])
    let clock = TestClock()
    let store = makeStore(TimetableFeature.State.sample(), service: service, clock: clock)

    await store.send(.festivalChanged("fst")) {
      $0.festivalID = "fst"
      $0.mySetIDs = []
      $0.scheduleSync = .loading
      $0.loadRequestID = 1
    }
    await store.receive(\.scheduleLoaded) {
      $0.scheduleSync = .localOnly
    }
    await store.send(.view(.setTapped("lime"))) {
      $0.selectedSetID = "lime"
    }
    await store.send(.view(.setScheduleToggled)) {
      $0.mySetIDs = ["lime"]
      $0.isScheduleToastVisible = true
    }
    #expect(service.replaced.value.isEmpty)
    await clock.advance(by: .seconds(2))
    await store.receive(\.scheduleToastExpired) {
      $0.isScheduleToastVisible = false
    }
  }

  @Test func rejectedSaveReloadsServerSchedule() async {
    var state = readyState(mine: ["lime"])
    state.isSaving = true
    let service = ScheduleServiceSpy(fetchResults: [.success(.init(setIDs: ["noise"]))])
    let store = makeStore(state, service: service)
    let save = TimetableFeature.ScheduleSave(setIDs: ["lime"], clientAt: beforeFestival, generation: 0)

    await store.send(.scheduleSaved(festivalID: "fst", save, .failure(.rejected))) {
      $0.isSaving = false
      $0.scheduleSync = .loading
      $0.loadRequestID = 1
    }
    await store.receive(\.scheduleLoaded) {
      $0.mySetIDs = ["noise"]
      $0.scheduleSync = .ready
    }
  }

  @Test func uncertainSaveIsResentAsTheSameRequest() async {
    var state = readyState(mine: ["lime"])
    state.isSaving = true
    let service = ScheduleServiceSpy()
    let store = makeStore(state, service: service)
    let save = TimetableFeature.ScheduleSave(setIDs: ["lime"], clientAt: beforeFestival, generation: 0)

    await store.send(.scheduleSaved(festivalID: "fst", save, .failure(.unavailable))) {
      $0.isSaving = false
      $0.uncertainSave = save
    }
    await store.send(.timetableAppeared) {
      $0.uncertainSave = nil
      $0.isSaving = true
    }
    await store.receive(\.scheduleSaved) {
      $0.isSaving = false
    }
    await store.receive(scheduleSaved(festivalID: "fst", setIDs: ["lime"]))
    #expect(service.replaced.value == [save])
  }

  @Test func uncertainSaveWithChangedScheduleReadsServerFirst() async {
    var state = readyState(mine: ["lime", "noise"])
    state.uncertainSave = .init(setIDs: ["lime"], clientAt: beforeFestival, generation: 0)
    let service = ScheduleServiceSpy(fetchResults: [.success(.init(setIDs: ["encore"]))])
    let store = makeStore(state, service: service)

    await store.send(.timetableAppeared) {
      $0.uncertainSave = nil
      $0.scheduleSync = .loading
      $0.loadRequestID = 1
    }
    await store.receive(\.scheduleLoaded) {
      $0.mySetIDs = ["encore"]
      $0.scheduleSync = .ready
    }
    #expect(service.replaced.value.isEmpty)
  }

  @Test func packUpdateRemovesDeletedSetsAndSaves() async {
    let service = ScheduleServiceSpy()
    let store = makeStore(readyState(mine: ["lime", "gone"]), service: service)

    await store.send(.packUpdated) {
      $0.mySetIDs = ["lime"]
      $0.isSaving = true
      $0.lastClientAt = self.beforeFestival
    }
    await store.receive(\.scheduleSaved) {
      $0.isSaving = false
    }
    await store.receive(scheduleSaved(festivalID: "fst", setIDs: ["lime"]))
    #expect(service.replaced.value.map(\.setIDs) == [["lime"]])
  }

  @Test func scheduleStopsAtLimit() async {
    let full = Set((0 ..< TimetableFeature.scheduleLimit).map { "set-\($0)" })
    let store = makeStore(readyState(mine: full, selected: "lime"), service: ScheduleServiceSpy())

    await store.send(.view(.setScheduleToggled)) {
      $0.isScheduleLimitReached = true
    }
  }

  @Test func endedSetCannotBeAdded() async {
    var state = TimetableFeature.State.sample()
    state.mySetIDs = []
    state.selectedSetID = "opening"
    let afterFirstDay = Date(timeIntervalSince1970: 1_786_028_400 + 2 * 24 * 60 * 60)
    let store = TestStore(initialState: state) {
      TimetableFeature()
    } withDependencies: {
      $0.date.now = afterFirstDay
    }

    await store.send(.view(.setScheduleToggled))
  }

  @Test func lateResultFromPreviousFestivalIsIgnored() async {
    var state = readyState()
    state.festivalID = "next"
    state.scheduleSync = .loading
    state.loadRequestID = 2
    let store = makeStore(state, service: ScheduleServiceSpy())

    await store.send(.scheduleLoaded(festivalID: "fst", requestID: 1, .success(.init(setIDs: ["lime"]))))
  }

  @Test func accountChangeClearsScheduleAndDropsPreviousLoad() async {
    var state = readyState(mine: ["lime"], selected: "lime")
    state.scheduleSync = .loading
    state.loadRequestID = 3
    state.isSaving = true
    state.needsSave = true
    state.isScheduleLimitReached = true
    state.lastClientAt = beforeFestival
    state.uncertainSave = .init(setIDs: ["lime"], clientAt: beforeFestival, generation: 0)
    let service = ScheduleServiceSpy(fetchResults: [.failure(.unauthorized)])
    let store = makeStore(state, service: service)

    await store.send(.accountChanged) {
      $0.mySetIDs = []
      $0.scheduleSync = .loading
      $0.isScheduleLimitReached = false
      $0.loadRequestID = 5
      $0.accountGeneration = 1
      $0.isSaving = false
      $0.needsSave = false
      $0.lastClientAt = nil
      $0.uncertainSave = nil
    }
    await store.receive(\.scheduleLoaded) {
      $0.scheduleSync = .localOnly
    }
    await store.send(.scheduleLoaded(festivalID: "fst", requestID: 3, .success(.init(setIDs: ["lime"]))))
    #expect(store.state.selectedSetID == "lime")
    #expect(service.fetchCount.value == 1)
  }

  @Test func previousAccountSaveCannotOverwriteCurrentSave() async {
    var state = readyState(mine: ["lime"], selected: "noise")
    state.isSaving = true
    let clock = TestClock()
    let (saveGate, saveContinuation) = AsyncStream<Void>.makeStream()
    let service = ScheduleServiceSpy(replaceDelay: {
      for await _ in saveGate { break }
    })
    let store = makeStore(state, service: service, clock: clock)
    let previous = TimetableFeature.ScheduleSave(setIDs: ["lime"], clientAt: beforeFestival, generation: 0)

    await store.send(.accountChanged) {
      $0.mySetIDs = []
      $0.scheduleSync = .loading
      $0.loadRequestID = 2
      $0.accountGeneration = 1
      $0.isSaving = false
    }
    await store.receive(\.scheduleLoaded) {
      $0.scheduleSync = .ready
    }
    await store.send(.view(.setScheduleToggled)) {
      $0.mySetIDs = ["noise"]
      $0.isScheduleToastVisible = true
      $0.isSaving = true
      $0.lastClientAt = self.beforeFestival
    }
    await store.send(.scheduleSaved(festivalID: "fst", previous, .failure(.stale(.init(setIDs: ["lime"])))))
    await store.send(.scheduleSaved(festivalID: "fst", previous, .success(.init(setIDs: ["lime"]))))
    #expect(store.state.isSaving)
    #expect(store.state.mySetIDs == ["noise"])
    saveContinuation.yield(())
    saveContinuation.finish()
    await store.receive(\.scheduleSaved) {
      $0.isSaving = false
    }
    await store.receive(scheduleSaved(festivalID: "fst", setIDs: ["noise"]))
    await clock.advance(by: .seconds(2))
    await store.receive(\.scheduleToastExpired) {
      $0.isScheduleToastVisible = false
    }
    #expect(store.state.mySetIDs == ["noise"])
    #expect(!store.state.isSaving)
    #expect(service.replaced.value.map(\.setIDs) == [["noise"]])
  }

  @Test func successfulSaveDelegatesSavedSnapshot() async {
    var state = readyState(mine: ["lime", "noise"])
    state.isSaving = true
    state.needsSave = true
    let service = ScheduleServiceSpy()
    let store = makeStore(state, service: service)
    let save = TimetableFeature.ScheduleSave(setIDs: ["lime"], clientAt: beforeFestival, generation: 0)

    await store.send(.scheduleSaved(festivalID: "fst", save, .success(.init(setIDs: ["lime"])))) {
      $0.needsSave = false
      $0.lastClientAt = self.beforeFestival
    }
    await store.receive(scheduleSaved(festivalID: "fst", setIDs: ["lime"]))
    await store.receive(\.scheduleSaved) {
      $0.isSaving = false
    }
    await store.receive(scheduleSaved(festivalID: "fst", setIDs: ["lime", "noise"]))
  }

  @Test func detailShowsTimeUntilStartAndStatus() {
    var state = TimetableFeature.State.sample()
    state.selectedSetID = "lime" // 17:00–17:50
    let firstDay = Date(timeIntervalSince1970: 1_786_028_400)

    let upcoming = state.setDetail(now: firstDay.addingTimeInterval(TimeInterval(15 * 60 * 60 + 28 * 60)))
    #expect(upcoming?.relativeTime == "1시간 32분 후")
    #expect(upcoming?.stage == "리벳 스테이지")
    #expect(upcoming?.time == "17:00–17:50 · 50분")
    #expect(state.setDetail(now: firstDay.addingTimeInterval(TimeInterval(16 * 60 * 60 + 20 * 60)))?.relativeTime == "40분 후")
    #expect(state.setDetail(now: firstDay.addingTimeInterval(TimeInterval(16 * 60 * 60)))?.relativeTime == "1시간 후")
    #expect(state.setDetail(now: firstDay.addingTimeInterval(TimeInterval(17 * 60 * 60 + 10 * 60)))?.status == .live)
    #expect(state.setDetail(now: firstDay.addingTimeInterval(TimeInterval(18 * 60 * 60)))?.status == .ended)
  }

  @Test func overlapAcrossMidnightIsDetected() {
    var state = TimetableFeature.State.sample()
    state.days[1].sets = [
      TimetableSet(id: "dawn", artist: "새벽 세션", stageID: "rivet", start: 30, end: 90),
    ]
    state.mySetIDs = ["midnight", "dawn"] // 1일차 23:30–다음날 01:30, 2일차 00:30–01:30
    state.selectedSetID = "midnight"

    let overlap = state.setDetail(now: beforeFestival)?.overlap
    #expect(overlap == TimetableSetOverlap(artist: "새벽 세션", stage: "리벳 스테이지", time: "00:30–01:30", minutes: 60))
    #expect(overlap?.warning == "새벽 세션(리벳 스테이지 00:30–01:30)과 60분 겹쳐요")
    #expect(state.overlaps == [TimetableOverlap(start: 1470, end: 1530)])
  }
}

// MARK: - 상세 시트 문구

extension TimetableScheduleTests {
  @Test func overlapWarningNamesStageTimeAndSharedMinutes() {
    var state = TimetableFeature.State.sample()
    state.mySetIDs = ["noise-returns", "cryingbird"] // 리벳 15:40–16:30, 원더 15:55–16:45
    state.selectedSetID = "noise-returns"

    #expect(state.setDetail(now: beforeFestival)?.overlap?.warning == "크라잉버드(원더 스테이지 15:55–16:45)와 35분 겹쳐요")
  }

  @Test func changedSetShowsPreviousTimeAndDuration() {
    var state = TimetableFeature.State.sample(variant: .changed)
    state.selectedSetID = "lime" // 16:40 → 17:00–17:50

    let detail = state.setDetail(now: beforeFestival)
    #expect(detail?.previousTime == "16:40")
    #expect(detail?.change == "20분 미뤄짐")
    #expect(detail?.time == "17:00–17:50 · 50분")
  }

  @Test func overlapWarningUsesParticleForNonHangulName() {
    let overlap = TimetableSetOverlap(artist: "NELL", stage: "원더 스테이지", time: "15:55–16:45", minutes: 35)

    #expect(overlap.warning == "NELL(원더 스테이지 15:55–16:45)와 35분 겹쳐요")
  }

  @Test func overlapWarningUsesParticleForDecomposedHangulName() {
    let decomposed = "새벽 세션".decomposedStringWithCanonicalMapping
    let overlap = TimetableSetOverlap(artist: decomposed, stage: "리벳 스테이지", time: "00:30–01:30", minutes: 60)

    #expect(overlap.warning.hasSuffix(")과 60분 겹쳐요"))
  }
}

// MARK: - 내 일정 토스트

extension TimetableScheduleTests {
  @Test func addingShowsToastForTwoSeconds() async {
    let clock = TestClock()
    let store = makeStore(readyState(selected: "lime"), service: ScheduleServiceSpy(), clock: clock)

    await store.send(.view(.setScheduleToggled)) {
      $0.mySetIDs = ["lime"]
      $0.isScheduleToastVisible = true
      $0.isSaving = true
      $0.lastClientAt = self.beforeFestival
    }
    await store.receive(\.scheduleSaved) {
      $0.isSaving = false
    }
    await store.receive(scheduleSaved(festivalID: "fst", setIDs: ["lime"]))
    await clock.advance(by: .milliseconds(1999))
    #expect(store.state.isScheduleToastVisible)
    await clock.advance(by: .milliseconds(1))
    await store.receive(\.scheduleToastExpired) {
      $0.isScheduleToastVisible = false
    }
  }

  @Test func removingHidesToastImmediately() async {
    let clock = TestClock()
    var state = readyState(selected: "lime")
    state.scheduleSync = .localOnly
    let store = makeStore(state, service: ScheduleServiceSpy(), clock: clock)

    await store.send(.view(.setScheduleToggled)) {
      $0.mySetIDs = ["lime"]
      $0.isScheduleToastVisible = true
    }
    await store.send(.view(.setScheduleToggled)) {
      $0.mySetIDs = []
      $0.isScheduleToastVisible = false
    }
    await clock.run()
  }

  @Test func dismissingSheetHidesToast() async {
    let clock = TestClock()
    var state = readyState(selected: "lime")
    state.scheduleSync = .localOnly
    let store = makeStore(state, service: ScheduleServiceSpy(), clock: clock)

    await store.send(.view(.setScheduleToggled)) {
      $0.mySetIDs = ["lime"]
      $0.isScheduleToastVisible = true
    }
    await store.send(.view(.setDetailDismissed)) {
      $0.selectedSetID = nil
      $0.isScheduleToastVisible = false
    }
    await clock.run()
  }

  @Test func selectingAnotherSetHidesToast() async {
    let clock = TestClock()
    var state = readyState(selected: "lime")
    state.scheduleSync = .localOnly
    let store = makeStore(state, service: ScheduleServiceSpy(), clock: clock)

    await store.send(.view(.setScheduleToggled)) {
      $0.mySetIDs = ["lime"]
      $0.isScheduleToastVisible = true
    }
    await store.send(.view(.setTapped("noise"))) {
      $0.selectedSetID = "noise"
      $0.isScheduleToastVisible = false
    }
    await clock.run()
  }

  @Test func festivalChangeHidesToast() async {
    let clock = TestClock()
    var state = readyState(selected: "lime")
    state.scheduleSync = .localOnly
    let store = makeStore(state, service: ScheduleServiceSpy(), clock: clock)

    await store.send(.view(.setScheduleToggled)) {
      $0.mySetIDs = ["lime"]
      $0.isScheduleToastVisible = true
    }
    await store.send(.festivalChanged("next")) {
      $0.festivalID = "next"
      $0.mySetIDs = []
      $0.selectedSetID = nil
      $0.scheduleSync = .loading
      $0.loadRequestID = 1
      $0.isScheduleToastVisible = false
    }
    await store.receive(\.scheduleLoaded) {
      $0.scheduleSync = .ready
    }
    await clock.run()
  }

  @Test func packUpdateClosingSelectedSetHidesToast() async {
    var state = readyState(selected: "gone")
    state.isScheduleToastVisible = true
    let store = makeStore(state, service: ScheduleServiceSpy())

    await store.send(.packUpdated) {
      $0.selectedSetID = nil
      $0.isScheduleToastVisible = false
    }
  }

  @Test func staleSaveRemovingAddedSetHidesToast() async {
    let clock = TestClock()
    let store = makeStore(readyState(selected: "lime"), service: StaleScheduleService(), clock: clock)

    await store.send(.view(.setScheduleToggled)) {
      $0.mySetIDs = ["lime"]
      $0.isScheduleToastVisible = true
      $0.isSaving = true
      $0.lastClientAt = self.beforeFestival
    }
    await store.receive(\.scheduleSaved) {
      $0.isSaving = false
      $0.mySetIDs = []
      $0.isScheduleToastVisible = false
    }
    await store.receive(scheduleSaved(festivalID: "fst", setIDs: []))
    await clock.run()
  }

  @Test func reloadAfterRejectedSaveRemovingAddedSetHidesToast() async {
    let clock = TestClock()
    var state = readyState(mine: ["lime"], selected: "lime")
    state.isSaving = true
    state.isScheduleToastVisible = true
    let store = makeStore(state, service: ScheduleServiceSpy(fetchResults: [.success(.init(setIDs: []))]), clock: clock)
    let save = TimetableFeature.ScheduleSave(setIDs: ["lime"], clientAt: beforeFestival, generation: 0)

    await store.send(.scheduleSaved(festivalID: "fst", save, .failure(.rejected))) {
      $0.isSaving = false
      $0.scheduleSync = .loading
      $0.loadRequestID = 1
    }
    await store.receive(\.scheduleLoaded) {
      $0.mySetIDs = []
      $0.scheduleSync = .ready
      $0.isScheduleToastVisible = false
    }
  }
}

private extension TimetableScheduleTests {
  func scheduleSaved(
    festivalID: String,
    setIDs: Set<String>
  ) -> (TimetableFeature.Action) -> Bool {
    { action in
      guard case let .delegate(.scheduleSaved(receivedID, receivedSetIDs)) = action else { return false }
      return receivedID == festivalID && receivedSetIDs == setIDs
    }
  }

  func readyState(
    mine: Set<String> = [],
    selected: String? = nil
  ) -> TimetableFeature.State {
    var state = TimetableFeature.State.sample()
    state.festivalID = "fst"
    state.mySetIDs = mine
    state.selectedSetID = selected
    state.scheduleSync = .ready
    return state
  }

  func makeStore(
    _ state: TimetableFeature.State,
    service: some FestivalScheduleService,
    clock: TestClock<Duration> = TestClock()
  ) -> TestStoreOf<TimetableFeature> {
    TestStore(initialState: state) {
      TimetableFeature()
    } withDependencies: {
      $0.festivalScheduleService = service
      $0.date.now = beforeFestival
      $0.continuousClock = clock
    }
  }
}

private struct ScheduleServiceSpy: FestivalScheduleService {
  let fetchResults: LockIsolated<[Result<FestivalSchedule, FestivalScheduleError>]>
  let fetchCount = LockIsolated(0)
  let replaced = LockIsolated<[TimetableFeature.ScheduleSave]>([])
  let replaceDelay: (@Sendable () async -> Void)?

  init(
    fetchResults: [Result<FestivalSchedule, FestivalScheduleError>] = [],
    replaceDelay: (@Sendable () async -> Void)? = nil
  ) {
    self.fetchResults = LockIsolated(fetchResults)
    self.replaceDelay = replaceDelay
  }

  func fetch(festivalID _: String) async throws(FestivalScheduleError) -> FestivalSchedule {
    fetchCount.withValue { $0 += 1 }
    let result = fetchResults.withValue { $0.isEmpty ? .success(.init(setIDs: [])) : $0.removeFirst() }
    return try result.get()
  }

  func replace(
    festivalID _: String,
    setIDs: [String],
    clientAt: Date
  ) async throws(FestivalScheduleError) -> FestivalSchedule {
    replaced.withValue { $0.append(.init(setIDs: setIDs, clientAt: clientAt, generation: 0)) }
    await replaceDelay?()
    return .init(setIDs: setIDs)
  }
}

/// 저장하면 다른 기기가 먼저 저장한 빈 목록을 돌려준다.
private struct StaleScheduleService: FestivalScheduleService {
  func fetch(festivalID _: String) async throws(FestivalScheduleError) -> FestivalSchedule {
    .init(setIDs: [])
  }

  func replace(
    festivalID _: String,
    setIDs _: [String],
    clientAt _: Date
  ) async throws(FestivalScheduleError) -> FestivalSchedule {
    throw .stale(.init(setIDs: []))
  }
}
