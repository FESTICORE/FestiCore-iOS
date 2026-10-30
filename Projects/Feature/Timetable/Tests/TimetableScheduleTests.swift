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
    let store = makeStore(state, service: service)
    let inFlight = TimetableFeature.ScheduleSave(setIDs: [], clientAt: beforeFestival)

    await store.send(.view(.setScheduleToggled)) {
      $0.mySetIDs = ["lime"]
      $0.needsSave = true
    }
    await store.send(.scheduleSaved(festivalID: "fst", inFlight, .success(.init(setIDs: [])))) {
      $0.needsSave = false
      $0.lastClientAt = self.beforeFestival.addingTimeInterval(0.001)
    }
    await store.receive(\.scheduleSaved) {
      $0.isSaving = false
    }
    // 같은 시각에 이어진 저장도 서버 충돌을 피하도록 1ms 늦춘다.
    #expect(service.replaced.value == [.init(setIDs: ["lime"], clientAt: beforeFestival.addingTimeInterval(0.001))])
  }

  @Test func staleSaveAdoptsServerScheduleAndDropsPendingChange() async {
    var state = readyState(mine: ["lime"])
    state.isSaving = true
    state.needsSave = true
    let service = ScheduleServiceSpy()
    let store = makeStore(state, service: service)
    let save = TimetableFeature.ScheduleSave(setIDs: [], clientAt: beforeFestival)

    await store.send(.scheduleSaved(festivalID: "fst", save, .failure(.stale(.init(setIDs: ["noise", "gone"]))))) {
      $0.isSaving = false
      $0.needsSave = false
      $0.mySetIDs = ["noise"]
    }
    #expect(service.replaced.value.isEmpty)
  }

  @Test func unauthorizedLoadKeepsScheduleOnDevice() async {
    let service = ScheduleServiceSpy(fetchResults: [.failure(.unauthorized)])
    let store = makeStore(TimetableFeature.State.sample(), service: service)

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
    }
    #expect(service.replaced.value.isEmpty)
  }

  @Test func rejectedSaveReloadsServerSchedule() async {
    var state = readyState(mine: ["lime"])
    state.isSaving = true
    let service = ScheduleServiceSpy(fetchResults: [.success(.init(setIDs: ["noise"]))])
    let store = makeStore(state, service: service)
    let save = TimetableFeature.ScheduleSave(setIDs: ["lime"], clientAt: beforeFestival)

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
    let save = TimetableFeature.ScheduleSave(setIDs: ["lime"], clientAt: beforeFestival)

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
    #expect(service.replaced.value == [save])
  }

  @Test func uncertainSaveWithChangedScheduleReadsServerFirst() async {
    var state = readyState(mine: ["lime", "noise"])
    state.uncertainSave = .init(setIDs: ["lime"], clientAt: beforeFestival)
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

  @Test func detailShowsTimeUntilStartAndStatus() {
    var state = TimetableFeature.State.sample()
    state.selectedSetID = "lime" // 17:00–17:50
    let firstDay = Date(timeIntervalSince1970: 1_786_028_400)

    let upcoming = state.setDetail(now: firstDay.addingTimeInterval(TimeInterval(15 * 60 * 60 + 28 * 60)))
    #expect(upcoming?.relativeTime == "1시간 32분 후 시작")
    #expect(upcoming?.stage == "리벳 스테이지")
    #expect(upcoming?.time == "17:00–17:50")
    #expect(state.setDetail(now: firstDay.addingTimeInterval(TimeInterval(16 * 60 * 60 + 20 * 60)))?.relativeTime == "40분 후 시작")
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

    #expect(state.setDetail(now: beforeFestival)?.overlappingArtists == ["새벽 세션"])
    #expect(state.overlaps == [TimetableOverlap(start: 1470, end: 1530)])
  }
}

private extension TimetableScheduleTests {
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
    service: ScheduleServiceSpy
  ) -> TestStoreOf<TimetableFeature> {
    TestStore(initialState: state) {
      TimetableFeature()
    } withDependencies: {
      $0.festivalScheduleService = service
      $0.date.now = beforeFestival
    }
  }
}

private struct ScheduleServiceSpy: FestivalScheduleService {
  let fetchResults: LockIsolated<[Result<FestivalSchedule, FestivalScheduleError>]>
  let fetchCount = LockIsolated(0)
  let replaced = LockIsolated<[TimetableFeature.ScheduleSave]>([])

  init(fetchResults: [Result<FestivalSchedule, FestivalScheduleError>] = []) {
    self.fetchResults = LockIsolated(fetchResults)
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
    replaced.withValue { $0.append(.init(setIDs: setIDs, clientAt: clientAt)) }
    return .init(setIDs: setIDs)
  }
}
