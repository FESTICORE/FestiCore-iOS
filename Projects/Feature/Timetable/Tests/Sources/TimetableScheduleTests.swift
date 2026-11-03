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

    await store.send(.view(.festivalChanged("fst"))) {
      $0.festivalID = "fst"
      $0.mySetIDs = []
      $0.scheduleSync = .loading
      $0.loadRequestID = 1
    }
    await store.receive(\.async.fetchSchedule)
    await store.receive(\.inner.scheduleLoaded) {
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

    await store.send(.view(.timetableAppeared))
    #expect(service.fetchCount.value == 0)
  }

  @Test func togglingWhileLoadingIsIgnored() async {
    var state = readyState()
    state.scheduleSync = .loading
    let store = makeStore(opening("lime", in: state), service: ScheduleServiceSpy())

    await store.send(scheduleToggled)
  }

  @Test func toggleSavesLatestSnapshotAfterInFlightSave() async {
    var state = readyState(selected: "lime")
    state.isSaving = true
    state.lastClientAt = beforeFestival
    let service = ScheduleServiceSpy()
    let clock = TestClock()
    let store = makeStore(state, service: service, clock: clock)
    let inFlight = TimetableFeature.ScheduleSave(setIDs: [], clientAt: beforeFestival, generation: 0)

    await store.send(scheduleToggled) {
      $0.mySetIDs = ["lime"]
      $0.needsSave = true
    }
    await store.receive(\.scope.setDetail.presented.inner.contentChanged) {
      $0.setDetail?.content.detail.isScheduled = true
    }
    await store.receive(\.scope.setDetail.presented.async.showScheduleToast) {
      $0.setDetail?.isScheduleToastVisible = true
    }
    await store.send(.inner(.scheduleSaved(festivalID: "fst", inFlight, .success(.init(setIDs: []))))) {
      $0.needsSave = false
      $0.lastClientAt = self.beforeFestival.addingTimeInterval(0.001)
    }
    await store.receive(scheduleSaved(festivalID: "fst", setIDs: []))
    await store.receive(\.async.replaceSchedule)
    await store.receive(\.inner.scheduleSaved) {
      $0.isSaving = false
    }
    await store.receive(scheduleSaved(festivalID: "fst", setIDs: ["lime"]))
    // 같은 시각에 이어진 저장도 서버 충돌을 피하도록 1ms 늦춘다.
    #expect(service.replaced.value == [.init(setIDs: ["lime"], clientAt: beforeFestival.addingTimeInterval(0.001), generation: 0)])
    await clock.advance(by: .seconds(2))
    await store.receive(\.scope.setDetail.presented.inner.scheduleToastExpired) {
      $0.setDetail?.isScheduleToastVisible = false
    }
  }

  @Test func staleSaveAdoptsServerScheduleAndDropsPendingChange() async {
    var state = readyState(mine: ["lime"])
    state.isSaving = true
    state.needsSave = true
    let service = ScheduleServiceSpy()
    let store = makeStore(state, service: service)
    let save = TimetableFeature.ScheduleSave(setIDs: [], clientAt: beforeFestival, generation: 0)

    await store.send(.inner(.scheduleSaved(festivalID: "fst", save, .failure(.stale(.init(setIDs: ["noise", "gone"])))))) {
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

    await store.send(.view(.festivalChanged("fst"))) {
      $0.festivalID = "fst"
      $0.mySetIDs = []
      $0.scheduleSync = .loading
      $0.loadRequestID = 1
    }
    await store.receive(\.async.fetchSchedule)
    await store.receive(\.inner.scheduleLoaded) {
      $0.scheduleSync = .localOnly
    }
    await store.send(.view(.setTapped("lime"))) {
      $0 = self.opening("lime", in: $0)
    }
    await store.send(scheduleToggled) {
      $0.mySetIDs = ["lime"]
    }
    await store.receive(\.scope.setDetail.presented.inner.contentChanged) {
      $0.setDetail?.content.detail.isScheduled = true
    }
    await store.receive(\.scope.setDetail.presented.async.showScheduleToast) {
      $0.setDetail?.isScheduleToastVisible = true
    }
    #expect(service.replaced.value.isEmpty)
    await clock.advance(by: .seconds(2))
    await store.receive(\.scope.setDetail.presented.inner.scheduleToastExpired) {
      $0.setDetail?.isScheduleToastVisible = false
    }
  }

  @Test func rejectedSaveReloadsServerSchedule() async {
    var state = readyState(mine: ["lime"])
    state.isSaving = true
    let service = ScheduleServiceSpy(fetchResults: [.success(.init(setIDs: ["noise"]))])
    let store = makeStore(state, service: service)
    let save = TimetableFeature.ScheduleSave(setIDs: ["lime"], clientAt: beforeFestival, generation: 0)

    await store.send(.inner(.scheduleSaved(festivalID: "fst", save, .failure(.rejected)))) {
      $0.isSaving = false
      $0.scheduleSync = .loading
      $0.loadRequestID = 1
    }
    await store.receive(\.async.fetchSchedule)
    await store.receive(\.inner.scheduleLoaded) {
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

    await store.send(.inner(.scheduleSaved(festivalID: "fst", save, .failure(.unavailable)))) {
      $0.isSaving = false
      $0.uncertainSave = save
    }
    await store.send(.view(.timetableAppeared)) {
      $0.uncertainSave = nil
      $0.isSaving = true
    }
    await store.receive(\.async.replaceSchedule)
    await store.receive(\.inner.scheduleSaved) {
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

    await store.send(.view(.timetableAppeared)) {
      $0.uncertainSave = nil
      $0.scheduleSync = .loading
      $0.loadRequestID = 1
    }
    await store.receive(\.async.fetchSchedule)
    await store.receive(\.inner.scheduleLoaded) {
      $0.mySetIDs = ["encore"]
      $0.scheduleSync = .ready
    }
    #expect(service.replaced.value.isEmpty)
  }

  @Test func packUpdateRemovesDeletedSetsAndSaves() async {
    let service = ScheduleServiceSpy()
    let store = makeStore(readyState(mine: ["lime", "gone"]), service: service)

    await store.send(.view(.packUpdated)) {
      $0.mySetIDs = ["lime"]
      $0.isSaving = true
      $0.lastClientAt = self.beforeFestival
    }
    await store.receive(\.async.replaceSchedule)
    await store.receive(\.inner.scheduleSaved) {
      $0.isSaving = false
    }
    await store.receive(scheduleSaved(festivalID: "fst", setIDs: ["lime"]))
    #expect(service.replaced.value.map(\.setIDs) == [["lime"]])
  }

  @Test func scheduleStopsAtLimit() async {
    let full = Set((0 ..< TimetableFeature.scheduleLimit).map { "set-\($0)" })
    let store = makeStore(readyState(mine: full, selected: "lime"), service: ScheduleServiceSpy())

    await store.send(scheduleToggled) {
      $0.isScheduleLimitReached = true
    }
    await store.receive(\.scope.setDetail.presented.inner.contentChanged) {
      $0.setDetail?.content.isScheduleLimitReached = true
    }
  }

  @Test func endedSetCannotBeAdded() async {
    var state = TimetableFeature.State.sample()
    state.mySetIDs = []
    let afterFirstDay = Date(timeIntervalSince1970: 1_786_028_400 + 2 * 24 * 60 * 60)
    let store = TestStore(initialState: opening("opening", in: state, now: afterFirstDay)) {
      TimetableFeature()
    } withDependencies: {
      $0.date.now = afterFirstDay
    }

    await store.send(scheduleToggled)
  }

  @Test func lateResultFromPreviousFestivalIsIgnored() async {
    var state = readyState()
    state.festivalID = "next"
    state.scheduleSync = .loading
    state.loadRequestID = 2
    let store = makeStore(state, service: ScheduleServiceSpy())

    await store.send(.inner(.scheduleLoaded(festivalID: "fst", requestID: 1, .success(.init(setIDs: ["lime"])))))
  }

  @Test func accountChangeClearsScheduleAndDropsPreviousLoad() async {
    var state = readyState(mine: ["lime"])
    state.scheduleSync = .loading
    state.loadRequestID = 3
    state.isSaving = true
    state.needsSave = true
    state.isScheduleLimitReached = true
    state.lastClientAt = beforeFestival
    state.uncertainSave = .init(setIDs: ["lime"], clientAt: beforeFestival, generation: 0)
    let service = ScheduleServiceSpy(fetchResults: [.failure(.unauthorized)])
    let store = makeStore(opening("lime", in: state), service: service)

    await store.send(.view(.accountChanged)) {
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
    await store.receive(\.scope.setDetail.presented.inner.contentChanged) {
      $0.setDetail?.content.detail.isScheduled = false
      $0.setDetail?.content.isScheduleLimitReached = false
    }
    await store.receive(\.async.fetchSchedule)
    await store.receive(\.inner.scheduleLoaded) {
      $0.scheduleSync = .localOnly
    }
    await store.receive(\.scope.setDetail.presented.inner.contentChanged) {
      $0.setDetail?.content.isScheduleLoading = false
    }
    await store.send(.inner(.scheduleLoaded(festivalID: "fst", requestID: 3, .success(.init(setIDs: ["lime"])))))
    #expect(store.state.setDetail?.setID == "lime")
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

    await store.send(.view(.accountChanged)) {
      $0.mySetIDs = []
      $0.scheduleSync = .loading
      $0.loadRequestID = 2
      $0.accountGeneration = 1
      $0.isSaving = false
    }
    await store.receive(\.scope.setDetail.presented.inner.contentChanged) {
      $0.setDetail?.content.isScheduleLoading = true
    }
    await store.receive(\.async.fetchSchedule)
    await store.receive(\.inner.scheduleLoaded) {
      $0.scheduleSync = .ready
    }
    await store.receive(\.scope.setDetail.presented.inner.contentChanged) {
      $0.setDetail?.content.isScheduleLoading = false
    }
    await store.send(scheduleToggled) {
      $0.mySetIDs = ["noise"]
      $0.isSaving = true
      $0.lastClientAt = self.beforeFestival
    }
    await store.receive(\.scope.setDetail.presented.inner.contentChanged) {
      $0.setDetail?.content.detail.isScheduled = true
    }
    await store.receive(\.scope.setDetail.presented.async.showScheduleToast) {
      $0.setDetail?.isScheduleToastVisible = true
    }
    await store.receive(\.async.replaceSchedule)
    await store.send(.inner(.scheduleSaved(festivalID: "fst", previous, .failure(.stale(.init(setIDs: ["lime"]))))))
    await store.send(.inner(.scheduleSaved(festivalID: "fst", previous, .success(.init(setIDs: ["lime"])))))
    #expect(store.state.isSaving)
    #expect(store.state.mySetIDs == ["noise"])
    saveContinuation.yield(())
    saveContinuation.finish()
    await store.receive(\.inner.scheduleSaved) {
      $0.isSaving = false
    }
    await store.receive(scheduleSaved(festivalID: "fst", setIDs: ["noise"]))
    await clock.advance(by: .seconds(2))
    await store.receive(\.scope.setDetail.presented.inner.scheduleToastExpired) {
      $0.setDetail?.isScheduleToastVisible = false
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

    await store.send(.inner(.scheduleSaved(festivalID: "fst", save, .success(.init(setIDs: ["lime"]))))) {
      $0.needsSave = false
      $0.lastClientAt = self.beforeFestival
    }
    await store.receive(scheduleSaved(festivalID: "fst", setIDs: ["lime"]))
    await store.receive(\.async.replaceSchedule)
    await store.receive(\.inner.scheduleSaved) {
      $0.isSaving = false
    }
    await store.receive(scheduleSaved(festivalID: "fst", setIDs: ["lime", "noise"]))
  }

  @Test func detailShowsTimeUntilStartAndStatus() {
    let state = TimetableFeature.State.sample() // lime 17:00–17:50
    let firstDay = Date(timeIntervalSince1970: 1_786_028_400)

    let upcoming = state.setDetailContent(id: "lime", now: firstDay.addingTimeInterval(TimeInterval(15 * 60 * 60 + 28 * 60)))
    #expect(upcoming?.detail.relativeTime == "1시간 32분 후")
    #expect(upcoming?.detail.stage == "리벳 스테이지")
    #expect(upcoming?.detail.time == "17:00–17:50 · 50분")
    #expect(state.setDetailContent(id: "lime", now: firstDay.addingTimeInterval(TimeInterval(16 * 60 * 60 + 20 * 60)))?.detail.relativeTime == "40분 후")
    #expect(state.setDetailContent(id: "lime", now: firstDay.addingTimeInterval(TimeInterval(16 * 60 * 60)))?.detail.relativeTime == "1시간 후")
    #expect(state.setDetailContent(id: "lime", now: firstDay.addingTimeInterval(TimeInterval(17 * 60 * 60 + 10 * 60)))?.detail.status == .live)
    #expect(state.setDetailContent(id: "lime", now: firstDay.addingTimeInterval(TimeInterval(18 * 60 * 60)))?.detail.status == .ended)
  }

  @Test func detailCarriesArtistImage() throws {
    var state = TimetableFeature.State.sample()
    let url = try #require(URL(string: "https://example.com/lime.webp"))
    let dayIndex = try #require(state.days.firstIndex { $0.sets.contains { $0.id == "lime" } })
    let setIndex = try #require(state.days[dayIndex].sets.firstIndex { $0.id == "lime" })
    state.days[dayIndex].sets[setIndex].imageURL = url
    let now = Date(timeIntervalSince1970: 1_786_028_400)

    #expect(state.setDetailContent(id: "lime", now: now)?.detail.imageURL == url)
    #expect(state.setDetailContent(id: "noise", now: now)?.detail.imageURL == nil)
  }

  @Test func overlapAcrossMidnightIsDetected() {
    var state = TimetableFeature.State.sample()
    state.days[1].sets = [
      TimetableSet(id: "dawn", artist: "새벽 세션", stageID: "rivet", start: 30, end: 90),
    ]
    state.mySetIDs = ["midnight", "dawn"] // 1일차 23:30–다음날 01:30, 2일차 00:30–01:30

    let overlap = state.setDetailContent(id: "midnight", now: beforeFestival)?.detail.overlap
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

    #expect(state.setDetailContent(id: "noise-returns", now: beforeFestival)?.detail.overlap?.warning == "크라잉버드(원더 스테이지 15:55–16:45)와 35분 겹쳐요")
  }

  @Test func changedSetShowsPreviousTimeAndDuration() {
    let state = TimetableFeature.State.sample(variant: .changed) // lime 16:40 → 17:00–17:50

    let detail = state.setDetailContent(id: "lime", now: beforeFestival)?.detail
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

    await store.send(scheduleToggled) {
      $0.mySetIDs = ["lime"]
      $0.isSaving = true
      $0.lastClientAt = self.beforeFestival
    }
    await store.receive(\.scope.setDetail.presented.inner.contentChanged) {
      $0.setDetail?.content.detail.isScheduled = true
    }
    await store.receive(\.scope.setDetail.presented.async.showScheduleToast) {
      $0.setDetail?.isScheduleToastVisible = true
    }
    await store.receive(\.async.replaceSchedule)
    await store.receive(\.inner.scheduleSaved) {
      $0.isSaving = false
    }
    await store.receive(scheduleSaved(festivalID: "fst", setIDs: ["lime"]))
    await clock.advance(by: .milliseconds(1999))
    #expect(store.state.setDetail?.isScheduleToastVisible == true)
    await clock.advance(by: .milliseconds(1))
    await store.receive(\.scope.setDetail.presented.inner.scheduleToastExpired) {
      $0.setDetail?.isScheduleToastVisible = false
    }
  }

  @Test func removingHidesToastImmediately() async {
    let clock = TestClock()
    let store = makeStore(localOnlyState(selected: "lime"), service: ScheduleServiceSpy(), clock: clock)

    await addLime(store)
    await store.send(scheduleToggled) {
      $0.mySetIDs = []
    }
    await store.receive(\.scope.setDetail.presented.inner.contentChanged) {
      $0.setDetail?.content.detail.isScheduled = false
      $0.setDetail?.isScheduleToastVisible = false
    }
    await clock.run()
  }

  @Test func dismissingSheetHidesToast() async {
    let clock = TestClock()
    let store = makeStore(localOnlyState(selected: "lime"), service: ScheduleServiceSpy(), clock: clock)

    await addLime(store)
    await store.send(.scope(.setDetail(.dismiss))) {
      $0.setDetail = nil
    }
    await clock.run()
  }

  @Test func selectingAnotherSetHidesToast() async {
    let clock = TestClock()
    let store = makeStore(localOnlyState(selected: "lime"), service: ScheduleServiceSpy(), clock: clock)

    await addLime(store)
    await store.send(.view(.setTapped("noise"))) {
      $0 = self.opening("noise", in: $0)
    }
    await clock.run()
  }

  @Test func festivalChangeHidesToast() async {
    let clock = TestClock()
    let store = makeStore(localOnlyState(selected: "lime"), service: ScheduleServiceSpy(), clock: clock)

    await addLime(store)
    await store.send(.view(.festivalChanged("next"))) {
      $0.festivalID = "next"
      $0.mySetIDs = []
      $0.setDetail = nil
      $0.scheduleSync = .loading
      $0.loadRequestID = 1
    }
    await store.receive(\.async.fetchSchedule)
    await store.receive(\.inner.scheduleLoaded) {
      $0.scheduleSync = .ready
    }
    await clock.run()
  }

  @Test func packUpdateClosingSelectedSetHidesToast() async {
    var state = opening("lime", in: readyState())
    state.setDetail = state.setDetail.map { TimetableSetDetailFeature.State(setID: "gone", content: $0.content) }
    state.setDetail?.isScheduleToastVisible = true
    let store = makeStore(state, service: ScheduleServiceSpy())

    await store.send(.view(.packUpdated)) {
      $0.setDetail = nil
    }
  }

  @Test func staleSaveRemovingAddedSetHidesToast() async {
    let clock = TestClock()
    let store = makeStore(readyState(selected: "lime"), service: StaleScheduleService(), clock: clock)

    await store.send(scheduleToggled) {
      $0.mySetIDs = ["lime"]
      $0.isSaving = true
      $0.lastClientAt = self.beforeFestival
    }
    await store.receive(\.scope.setDetail.presented.inner.contentChanged) {
      $0.setDetail?.content.detail.isScheduled = true
    }
    await store.receive(\.scope.setDetail.presented.async.showScheduleToast) {
      $0.setDetail?.isScheduleToastVisible = true
    }
    await store.receive(\.async.replaceSchedule)
    await store.receive(\.inner.scheduleSaved) {
      $0.isSaving = false
      $0.mySetIDs = []
    }
    await store.receive(\.scope.setDetail.presented.inner.contentChanged) {
      $0.setDetail?.content.detail.isScheduled = false
      $0.setDetail?.isScheduleToastVisible = false
    }
    await store.receive(scheduleSaved(festivalID: "fst", setIDs: []))
    await clock.run()
  }

  @Test func reloadAfterRejectedSaveRemovingAddedSetHidesToast() async {
    let clock = TestClock()
    var state = readyState(mine: ["lime"], selected: "lime")
    state.isSaving = true
    state.setDetail?.isScheduleToastVisible = true
    let store = makeStore(state, service: ScheduleServiceSpy(fetchResults: [.success(.init(setIDs: []))]), clock: clock)
    let save = TimetableFeature.ScheduleSave(setIDs: ["lime"], clientAt: beforeFestival, generation: 0)

    await store.send(.inner(.scheduleSaved(festivalID: "fst", save, .failure(.rejected)))) {
      $0.isSaving = false
      $0.scheduleSync = .loading
      $0.loadRequestID = 1
    }
    await store.receive(\.scope.setDetail.presented.inner.contentChanged) {
      $0.setDetail?.content.isScheduleLoading = true
    }
    await store.receive(\.async.fetchSchedule)
    await store.receive(\.inner.scheduleLoaded) {
      $0.mySetIDs = []
      $0.scheduleSync = .ready
    }
    await store.receive(\.scope.setDetail.presented.inner.contentChanged) {
      $0.setDetail?.content.detail.isScheduled = false
      $0.setDetail?.content.isScheduleLoading = false
      $0.setDetail?.isScheduleToastVisible = false
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

  var scheduleToggled: TimetableFeature.Action {
    .scope(.setDetail(.presented(.delegate(.scheduleToggled))))
  }

  func readyState(
    mine: Set<String> = [],
    selected: String? = nil
  ) -> TimetableFeature.State {
    var state = TimetableFeature.State.sample()
    state.festivalID = "fst"
    state.mySetIDs = mine
    state.scheduleSync = .ready
    return selected.map { opening($0, in: state) } ?? state
  }

  /// 서버 없이 이 기기에만 저장하는 상태에서 상세 시트를 연다.
  func localOnlyState(selected: String) -> TimetableFeature.State {
    var state = readyState()
    state.scheduleSync = .localOnly
    return opening(selected, in: state)
  }

  /// 현재 상태로 계산한 내용으로 상세 시트를 연다.
  func opening(
    _ id: String,
    in state: TimetableFeature.State,
    now: Date? = nil
  ) -> TimetableFeature.State {
    var state = state
    state.setDetail = state.setDetailContent(id: id, now: now ?? beforeFestival).map {
      TimetableSetDetailFeature.State(setID: id, content: $0)
    }
    return state
  }

  /// 열린 lime 시트에서 내 일정에 넣고 토스트가 뜨는 것까지 확인한다.
  func addLime(_ store: TestStoreOf<TimetableFeature>) async {
    await store.send(scheduleToggled) {
      $0.mySetIDs = ["lime"]
    }
    await store.receive(\.scope.setDetail.presented.inner.contentChanged) {
      $0.setDetail?.content.detail.isScheduled = true
    }
    await store.receive(\.scope.setDetail.presented.async.showScheduleToast) {
      $0.setDetail?.isScheduleToastVisible = true
    }
  }

  func makeStore(
    _ state: TimetableFeature.State,
    service: some FestivalScheduleService,
    clock: TestClock<Duration> = TestClock()
  ) -> TestStoreOf<TimetableFeature> {
    TestStore(initialState: state) {
      TimetableFeature()
    } withDependencies: {
      $0.festivalScheduleUseCase = MockFestivalScheduleUseCase(
        mySchedule: { festivalID throws(FestivalScheduleError) in
          try await service.fetch(festivalID: festivalID)
        },
        saveMySchedule: { festivalID, setIDs, clientAt throws(FestivalScheduleError) in
          try await service.replace(festivalID: festivalID, setIDs: setIDs, clientAt: clientAt)
        }
      )
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
    // 실제 요청처럼 한 번 양보한다. 바로 실패하면 시트 토스트 타이머가 시작되기 전에 응답이 와 버린다.
    await Task.yield()
    throw .stale(.init(setIDs: []))
  }
}
