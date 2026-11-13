import ComposableArchitecture
import FestiCoreAnalyticsInterface
import Foundation
import FestivalDomainInterface
import Testing
import TimetableDomainInterface
@testable import Timetable

@MainActor
struct TimetableFeatureTests {
  @Test func enablingPackNotificationsOnlyChangesPackUpdates() async {
    let changes = LockIsolated<[[FestivalNotificationKind: Bool]]>([])
    let store = TestStore(initialState: TimetableFeature.State(
      days: [],
      source: ""
    )) {
      TimetableFeature()
    } withDependencies: {
      $0.festivalNotificationSettingsUseCase = MockFestivalNotificationSettingsUseCase(
        permission: { .allowed },
        settings: { FestivalNotificationSettings(packUpdates: false) },
        updateSettings: { value in
          changes.withValue { $0.append(value) }
          return FestivalNotificationSettings(packUpdates: true)
        }
      )
    }
    await store.send(.view(.enablePackNotifications)) { $0.notificationStatus = .saving }
    await store.receive(\.async.enablePackNotifications)
    await store.receive(\.inner.notificationUpdated) { $0.notificationStatus = .enabled }
    #expect(changes.value == [[.packUpdates: true]])
  }

  @Test func enabledSubscriptionStillExplainsMissingDevicePermission() async {
    let store = TestStore(initialState: TimetableFeature.State(
      days: [],
      source: ""
    )) {
      TimetableFeature()
    } withDependencies: {
      $0.festivalNotificationSettingsUseCase = MockFestivalNotificationSettingsUseCase(
        permission: { .denied },
        settings: { FestivalNotificationSettings(packUpdates: true) }
      )
    }
    await store.send(.view(.enablePackNotifications)) { $0.notificationStatus = .saving }
    await store.receive(\.async.enablePackNotifications)
    await store.receive(\.inner.notificationUpdated) { $0.notificationStatus = .permissionRequired }
  }

  @Test func setListSearchAndChangesUseActualPerformances() {
    let days = TimetableFeature.State.sample(variant: .changed).days
    let search = TimetableSetListFeature.State(
      mode: .search,
      days: days,
      query: "라임"
    )
    #expect(search.results.flatMap(\.sets).map(\.id) == ["lime"])
    let changes = TimetableSetListFeature.State(
      mode: .changes,
      days: days
    )
    #expect(changes.results.flatMap(\.sets).count == 2)
  }

  @Test func clockRefreshesOnEntryTickAndDayChangeThenCancels() async {
    let clock = TestClock()
    let initial = TimetableFeature.State.sample()
    let date = LockIsolated(initial.days[0].date.addingTimeInterval(928 * 60))
    let analytics = LockIsolated<[AnalyticsEvent]>([])
    let store = TestStore(initialState: initial) {
      TimetableFeature()
    } withDependencies: {
      $0.continuousClock = clock
      $0.date = DateGenerator { date.value }
      $0.analyticsUseCase.track = { event in analytics.withValue { $0.append(event) } }
    }

    await store.send(.view(.clockStarted)) {
      $0.clockDate = date.value
    }
    #expect(analytics.value == [.screenView(
      screen: .timetable,
      referrer: nil
    )])
    await store.receive(\.async.observeClock)
    date.withValue { $0 = $0.addingTimeInterval(60) }
    await clock.advance(by: .seconds(1))
    await store.receive(\.inner.clockUpdated) {
      $0.clockDate = date.value
      $0.nowMinute = 929
    }
    await store.send(.view(.daySelected(1))) {
      $0.selectedDayIndex = 1
      $0.nowMinute = nil
    }
    await store.send(.view(.daySelected(0))) {
      $0.selectedDayIndex = 0
      $0.nowMinute = 929
    }
    await store.send(.view(.clockStopped))
    await clock.advance(by: .seconds(2))
    await store.finish()
  }

  @Test func currentTimeContinuesThroughCrossMidnightSet() async {
    var state = TimetableFeature.State.sample()
    state.days[0].sets = [state.days[0].sets[0]]
    state.days[0].sets[0].end = 1500
    let date = state.days[0].date.addingTimeInterval(1460 * 60)
    let store = TestStore(initialState: state) {
      TimetableFeature()
    }
    await store.send(.inner(.clockUpdated(date))) {
      $0.clockDate = date
      $0.nowMinute = 1460
    }
    await store.send(.inner(.clockUpdated(date.addingTimeInterval(40 * 60)))) {
      $0.clockDate = date.addingTimeInterval(40 * 60)
      $0.nowMinute = nil
    }
  }

  @Test func contentStatusDoesNotInferPublicationFromEmptyLineup() {
    var state = TimetableFeature.State(
      days: [],
      source: ""
    )
    for status in [TimetableFeature.ContentStatus.loading, .failed, .noFestival, .unpublished] {
      state.contentStatus = status
      #expect(!state.isPublished)
      #expect(!state.canPickSchedule)
    }
    state.contentStatus = .published
    #expect(state.isPublished)
  }

  @Test func retryAsksParentToReloadPack() async {
    let store = TestStore(initialState: TimetableFeature.State(
      days: [],
      source: ""
    )) {
      TimetableFeature()
    }
    await store.send(.view(.retryTapped))
    await store.receive(\.delegate.retry)
  }

  @Test func tappingSetOpensDetailWithoutChangingSchedule() async {
    // 샘플 첫날(2026-08-07 KST) 정오. lime(17:00–17:50)은 5시간 뒤 시작한다.
    let now = Date(timeIntervalSince1970: 1_786_028_400 + 12 * 60 * 60)
    let store = TestStore(initialState: TimetableFeature.State.sample()) {
      TimetableFeature()
    } withDependencies: {
      $0.date.now = now
    }

    await store.send(.view(.setTapped("lime"))) {
      $0.setDetail = TimetableSetDetailFeature.State(
        setID: "lime",
        content: .init(
          detail: TimetableSetDetail(
            artist: "라임플래그스",
            stage: "리벳 스테이지",
            time: "17:00–17:50 · 50분",
            status: .upcoming(minutes: 300),
            isScheduled: false
          ),
          interval: DateInterval(
            start: now.addingTimeInterval(5 * 60 * 60),
            end: now.addingTimeInterval(5 * 60 * 60 + 50 * 60)
          ),
          source: $0.source,
          isScheduleLoading: false,
          isScheduleLimitReached: false
        )
      )
    }
    await store.send(.scope(.setDetail(.dismiss))) {
      $0.setDetail = nil
    }
  }

  @Test func detailViewToggleAsksParentToSave() async {
    let store = TestStore(initialState: TimetableSetDetailFeature.State(setID: "lime", content: .sample)) {
      TimetableSetDetailFeature()
    }

    await store.send(.view(.scheduleToggled))
    await store.receive(\.delegate.scheduleToggled)
  }

  @Test func detailStatusFollowsCurrentTime() {
    let state = TimetableSetDetailFeature.State(setID: "lime", content: .sample)
    let start = TimetableSetDetailFeature.Content.sample.interval.start

    #expect(state.detail(now: start.addingTimeInterval(-90 * 60)).relativeTime == "1시간 30분 후")
    #expect(state.detail(now: start.addingTimeInterval(10 * 60)).status == .live)
    #expect(state.detail(now: start.addingTimeInterval(50 * 60)).status == .ended)
  }

  @Test func outOfRangeDayIsIgnored() async {
    let store = TestStore(initialState: TimetableFeature.State.sample()) {
      TimetableFeature()
    }

    await store.send(.view(.daySelected(2))) {
      $0.selectedDayIndex = 2
    }
    await store.send(.view(.daySelected(3)))
  }

  @Test func swipingPastFirstDayIsIgnored() async {
    let store = TestStore(initialState: TimetableFeature.State.sample()) {
      TimetableFeature()
    }

    await store.send(.view(.daySelected(-1)))
    await store.send(.view(.daySelected(1))) {
      $0.selectedDayIndex = 1
    }
    await store.send(.view(.daySelected(0))) {
      $0.selectedDayIndex = 0
    }
  }

  @Test func daySwipeNeedsMostlyHorizontalDrag() {
    #expect(TimetableBoard.dayOffset(forSwipe: CGSize(width: -81, height: 0)) == 1)
    #expect(TimetableBoard.dayOffset(forSwipe: CGSize(width: 81, height: 20)) == -1)
    #expect(TimetableBoard.dayOffset(forSwipe: CGSize(width: -80, height: 0)) == nil)
    #expect(TimetableBoard.dayOffset(forSwipe: CGSize(width: -120, height: 80)) == nil)
    #expect(TimetableBoard.dayOffset(forSwipe: CGSize(width: 20, height: 200)) == nil)
  }

  @Test func mineOnlyAndDayChangesTrackAnalyticsEvents() async {
    var state = TimetableFeature.State.sample()
    state.festivalID = "fst"
    let analytics = LockIsolated<[AnalyticsEvent]>([])
    let store = TestStore(initialState: state) {
      TimetableFeature()
    } withDependencies: {
      $0.analyticsUseCase.track = { event in analytics.withValue { $0.append(event) } }
    }

    await store.send(.view(.mineOnlyToggled)) {
      $0.showsMineOnly.toggle()
    }
    await store.send(.view(.daySelected(0)))
    await store.send(.view(.daySelected(1))) {
      $0.selectedDayIndex = 1
    }
    #expect(analytics.value == [
      .timetableAction(TimetableActionData(
        action: .mineOnlyToggle,
        festivalID: "fst"
      )),
      .timetableAction(TimetableActionData(
        action: .daySelect,
        festivalID: "fst"
      ))
    ])
  }

  @Test func pinchZoomIsKeptAcrossDayChanges() async {
    let store = TestStore(initialState: TimetableFeature.State.sample()) {
      TimetableFeature()
    }

    await store.send(.view(.zoomChanged(1.8))) {
      $0.zoom = 1.8
    }
    await store.send(.view(.daySelected(1))) {
      $0.selectedDayIndex = 1
    }
    #expect(store.state.zoom == 1.8)
  }

  @Test func bannerAsksParentToShowChanges() async {
    let store = TestStore(initialState: TimetableFeature.State.sample(variant: .changed)) {
      TimetableFeature()
    }

    await store.send(.view(.changeBannerTapped))
    await store.receive(\.delegate.showChanges)
  }

  @Test func overlapsCoverOnlyMySets() {
    let state = TimetableFeature.State.sample()

    #expect(state.mySetCount == 4)
    #expect(state.overlaps == [TimetableOverlap(start: 955, end: 990)])
    #expect(state.overlaps.first?.minutes == 35)
    #expect(state.visibleOverlaps.isEmpty)

    var changed = state
    changed.shouldShowOverlapWarning = true
    #expect(changed.visibleOverlaps == state.overlaps)
  }

  @Test func addingAnOverlappingSetShowsTheBoardWarning() throws {
    let feature = TimetableFeature()
    var state = TimetableFeature.State.sample()
    state.mySetIDs = ["noise-returns"]
    let now = try #require(state.selectedDay?.date.addingTimeInterval(928 * 60))
    let content = try #require(state.setDetailContent(
      id: "cryingbird",
      now: now
    ))
    state.setDetail = TimetableSetDetailFeature.State(
      setID: "cryingbird",
      content: content
    )

    withDependencies {
      $0.date.now = now
    } operation: {
      _ = feature.toggleSchedule(state: &state)
    }

    #expect(state.mySetIDs.contains("cryingbird"))
    #expect(state.shouldShowOverlapWarning)
    #expect(state.visibleOverlaps.first?.minutes == 35)
  }

  @Test func changingDayHidesTheOverlapWarning() async {
    var state = TimetableFeature.State.sample()
    state.shouldShowOverlapWarning = true
    let store = TestStore(initialState: state) {
      TimetableFeature()
    }

    await store.send(.view(.daySelected(0)))
    #expect(store.state.visibleOverlaps.count == 1)

    await store.send(.view(.daySelected(1))) {
      $0.selectedDayIndex = 1
      $0.shouldShowOverlapWarning = false
    }
    await store.send(.view(.daySelected(0))) {
      $0.selectedDayIndex = 0
    }
    #expect(store.state.overlaps.count == 1)
    #expect(store.state.visibleOverlaps.isEmpty)
  }

  @Test func changedSetsAreCounted() {
    #expect(TimetableFeature.State.sample(variant: .changed).selectedDay?.changedCount == 2)
    #expect(TimetableFeature.State.sample().selectedDay?.changedCount == 0)
  }

  @Test func unpublishedStateShowsLineup() {
    let state = TimetableFeature.State.sample(variant: .unpublished)

    #expect(!state.isPublished)
    #expect(state.lineup.map(\.artists.count) == [5, 4])
  }
}

private extension TimetableSetDetailFeature.Content {
  static let sample = Self(
    detail: TimetableSetDetail(
      artist: "라임",
      stage: "리벳 스테이지",
      time: "17:00–17:50 · 50분",
      status: .upcoming(minutes: 30),
      isScheduled: false
    ),
    interval: DateInterval(start: Date(timeIntervalSince1970: 1_786_089_600), duration: 50 * 60),
    source: "",
    isScheduleLoading: false,
    isScheduleLimitReached: false
  )
}
