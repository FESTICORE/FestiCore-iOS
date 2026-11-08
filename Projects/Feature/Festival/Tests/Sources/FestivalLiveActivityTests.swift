import Clocks
import ComposableArchitecture
import FestivalDomainInterface
import Foundation
import Testing
@testable import Festival

struct HomeLiveActivityTests {
  @Test @MainActor func savedPerformanceStartsAutomaticallyAtTwoHourWindowOnce() async {
    let now = ISO8601DateFormatter().date(from: "2026-10-29T08:00:00Z")!
    let start = ISO8601DateFormatter().date(from: "2026-10-29T09:00:00Z")!
    let end = ISO8601DateFormatter().date(from: "2026-10-30T09:00:00Z")!
    let performanceStart = ISO8601DateFormatter().date(from: "2026-10-29T10:00:00Z")!
    let starts = LockIsolated(0)
    let clock = TestClock()
    var state = FestivalFeature.State(selectedFestivalID: "festival")
    state.catalog = [festival(id: "festival")]
    state.selectedPack = savedPerformancePack()
    state.hasSession = true
    state.mySchedule = .init(
      festivalID: "festival",
      setIDs: ["saved-set"]
    )
    state.liveActivity.isReady = true
    state.liveActivity.now = now
    state.hasStarted = true
    let store = TestStore(initialState: state) { FestivalFeature() } withDependencies: {
      $0.useServiceBackedFestivalUseCases()
      $0.date.now = now
      $0.continuousClock = clock
      $0.festivalLiveActivityClient = .init(
        activities: { [] },
        changes: { AsyncStream { $0.finish() } },
        start: { _, _, _, _, _ in
          starts.withValue { $0 += 1 }
          return "automatic-activity"
        },
        update: { _, _, _, _, _, _ in },
        finish: { _, _ in },
        end: { _ in }
      )
    }

    await store.send(.inner(.liveActivityBoundary))
    await store.receive(\.inner.autoStartLiveActivity) {
      $0.autoActivityHandledStarts["festival"] = performanceStart
      $0.liveActivity.busyFestivalID = "festival"
      $0.liveActivity.revision = 1
    }
    await store.receive(\.async.startLiveActivity)
    await store.receive(\.inner.liveActivityStarted) {
      $0.liveActivity.busyFestivalID = nil
      $0.liveActivity.revision = 2
      $0.liveActivity.activities["festival"] = .init(
        id: "automatic-activity",
        festivalID: "festival",
        phase: .upcoming,
        startDate: start,
        endDate: end
      )
    }
    #expect(starts.value == 1)
    await store.send(.inner(.liveActivityBoundary))
    #expect(starts.value == 1)
    await store.send(.view(.foregroundChanged(false))) {
      $0.isForeground = false
    }
    await store.receive(\.async.prefetchImages)
    await store.finish()
  }

  @Test @MainActor func handledPerformanceDoesNotAutoRestart() async {
    let now = ISO8601DateFormatter().date(from: "2026-10-29T08:30:00Z")!
    let performanceStart = ISO8601DateFormatter().date(from: "2026-10-29T10:00:00Z")!
    var state = FestivalFeature.State(selectedFestivalID: "festival")
    state.catalog = [festival(id: "festival")]
    state.selectedPack = savedPerformancePack()
    state.hasSession = true
    state.mySchedule = .init(
      festivalID: "festival",
      setIDs: ["saved-set"]
    )
    state.liveActivity.isReady = true
    state.liveActivity.now = now
    state.hasStarted = true
    state.autoActivityHandledStarts["festival"] = performanceStart
    let store = TestStore(initialState: state) { FestivalFeature() } withDependencies: {
      $0.useServiceBackedFestivalUseCases()
      $0.date.now = now
      $0.continuousClock = TestClock()
    }

    await store.send(.inner(.liveActivityBoundary))
    await store.send(.view(.foregroundChanged(false))) {
      $0.isForeground = false
    }
    await store.receive(\.async.prefetchImages)
    await store.finish()
  }

  @Test func controlVisibilityRequiresActiveActivityOrValidSavedPerformance() throws {
    var state = FestivalFeature.State(selectedFestivalID: "festival")
    state.catalog = [festival(id: "festival")]
    state.selectedPack = try JSONDecoder().decode(
      FestivalPackDocument.self,
      from: Data(#"""
      {"id":"festival","timetable":[
        {"id":"valid","startsAt":"2026-10-29T09:00:00Z","endsAt":"2026-10-29T10:00:00Z"},
        {"id":"invalid","startsAt":"2026-10-29T10:00:00Z","endsAt":"2026-10-29T09:00:00Z"}
      ]}
      """#.utf8))
    #expect(!state.showsLiveActivityControl)
    state.mySchedule = .init(
      festivalID: "other",
      setIDs: ["valid"]
    )
    #expect(!state.showsLiveActivityControl)
    state.mySchedule = .init(
      festivalID: "festival",
      setIDs: ["invalid"]
    )
    #expect(!state.showsLiveActivityControl)
    state.mySchedule = .init(
      festivalID: "festival",
      setIDs: ["valid"]
    )
    #expect(state.showsLiveActivityControl)
    state.mySchedule = nil
    state.liveActivity.activities["festival"] = .init(
      id: "activity",
      festivalID: "festival",
      phase: .ongoing,
      startDate: Date(timeIntervalSince1970: 0),
      endDate: nil
    )
    #expect(state.showsLiveActivityControl)
  }

  @Test @MainActor func startThatCanNoLongerResolveReleasesBusyState() async {
    var state = FestivalFeature.State()
    state.liveActivity.isReady = true
    state.liveActivity.busyFestivalID = "missing"
    let store = TestStore(initialState: state) { FestivalFeature() }

    await store.send(.async(.startLiveActivity(festivalID: "missing"))) {
      $0.liveActivity.busyFestivalID = nil
    }
  }

  @Test @MainActor func startIsDisabledUntilOSActivitiesAreRestored() async {
    var state = FestivalFeature.State()
    state.catalog = [festival(id: "festival")]
    state.selectedFestivalID = "festival"
    let store = TestStore(initialState: state) { FestivalFeature() } withDependencies: {
      $0.useServiceBackedFestivalUseCases()
    }

    await store.send(.view(.liveActivityTapped))
    #expect(!store.state.liveActivityState.isEnabled)
    await store.finish()
  }

  @Test @MainActor func successfulStartCanBeStoppedByUser() async {
    let now = ISO8601DateFormatter().date(from: "2026-10-29T09:30:00Z")!
    let startDate = ISO8601DateFormatter().date(from: "2026-10-29T09:00:00Z")!
    let endDate = ISO8601DateFormatter().date(from: "2026-10-30T09:00:00Z")!
    let clock = TestClock()
    var state = FestivalFeature.State()
    state.catalog = [festival(id: "festival")]
    state.selectedFestivalID = "festival"
    state.selectedPack = savedPerformancePack()
    state.hasSession = true
    state.mySchedule = .init(
      festivalID: "festival",
      setIDs: ["saved-set"]
    )
    state.liveActivity.isReady = true
    state.hasStarted = true
    state.liveActivity.now = now
    let store = TestStore(initialState: state) { FestivalFeature() } withDependencies: {
      $0.useServiceBackedFestivalUseCases()
      $0.date.now = now
      $0.continuousClock = clock
      $0.festivalLiveActivityClient = .init(
        activities: { [] },
        changes: { AsyncStream { $0.finish() } },
        start: { _, _, _, _, _ in "activity" },
        update: { _, _, _, _, _, _ in },
        finish: { _, _ in },
        end: { _ in }
      )
    }

    await store.send(.view(.liveActivityTapped)) {
      $0.liveActivity.busyFestivalID = "festival"
      $0.liveActivity.revision = 1
    }
    await store.receive(\.async.startLiveActivity)
    await store.receive(\.inner.liveActivityStarted) {
      $0.liveActivity.busyFestivalID = nil
      $0.liveActivity.revision = 2
      $0.liveActivity.activities["festival"] = .init(
        id: "activity",
        festivalID: "festival",
        phase: .ongoing,
        startDate: startDate,
        endDate: endDate
      )
    }
    #expect(store.state.liveActivityState.title == "Live Activity 끄기")
    await store.send(.view(.liveActivityTapped)) {
      $0.liveActivity.busyFestivalID = "festival"
      $0.liveActivity.revision = 3
      $0.autoActivityHandledStarts["festival"] = ISO8601DateFormatter().date(from: "2026-10-29T10:00:00Z")!
    }
    await store.receive(\.async.endLiveActivity)
    await store.receive(\.inner.liveActivityStopped) {
      $0.liveActivity.busyFestivalID = nil
      $0.liveActivity.revision = 4
      $0.liveActivity.activities = [:]
    }
    await store.send(.view(.foregroundChanged(false))) {
      $0.isForeground = false
    }
    await store.receive(\.async.prefetchImages)
    await store.finish()
  }

  @Test func savedPerformanceControlsManualStartWindow() throws {
    let start = ISO8601DateFormatter().date(from: "2026-10-29T10:00:00Z")!
    let pack = savedPerformancePack()
    var state = FestivalFeature.State()
    state.catalog = [festival(id: "festival")]
    state.selectedFestivalID = "festival"
    state.selectedPack = pack
    state.hasSession = true
    state.mySchedule = .init(
      festivalID: "festival",
      setIDs: ["saved-set"]
    )
    state.liveActivity.isReady = true

    state.liveActivity.now = start.addingTimeInterval(-7_201)
    #expect(!state.liveActivityState.isEnabled)
    state.liveActivity.now = start.addingTimeInterval(-7_200)
    #expect(state.liveActivityState.isEnabled)
    state.liveActivity.now = start
    #expect(!state.liveActivityState.isEnabled)

    state.liveActivity.now = start.addingTimeInterval(-7_200)
    state.mySchedule = .init(
      festivalID: "festival",
      setIDs: []
    )
    #expect(!state.liveActivityState.isEnabled)
    state.mySchedule = .init(
      festivalID: "festival",
      setIDs: ["saved-set"]
    )
    state.hasSession = false
    #expect(!state.liveActivityState.isEnabled)
  }

  @Test @MainActor func nonSelectedFestivalReceivesScheduleUpdate() async {
    let now = ISO8601DateFormatter().date(from: "2026-10-29T09:30:00Z")!
    let oldStart = now.addingTimeInterval(-7_200)
    let startDate = ISO8601DateFormatter().date(from: "2026-10-29T09:00:00Z")!
    let endDate = ISO8601DateFormatter().date(from: "2026-10-30T09:00:00Z")!
    let clock = TestClock()
    var state = FestivalFeature.State()
    state.catalog = [festival(id: "selected"), festival(id: "other")]
    state.selectedFestivalID = "selected"
    state.liveActivity.isReady = true
    state.hasStarted = true
    state.liveActivity.now = now
    state.liveActivity.activities["other"] = .init(
      id: "activity-other",
      festivalID: "other",
      phase: .ongoing,
      startDate: oldStart,
      endDate: endDate
    )
    let store = TestStore(initialState: state) { FestivalFeature() } withDependencies: {
      $0.useServiceBackedFestivalUseCases()
      $0.date.now = now
      $0.continuousClock = clock
      $0.festivalLiveActivityClient = .init(
        activities: { [] },
        changes: { AsyncStream { $0.finish() } },
        start: { _, _, _, _, _ in "unused" },
        update: { id, phase, start, end, _, savedSetIDs in
          #expect(id == "activity-other")
          // 선택하지 않은 축제의 내 일정은 모르므로 비우지 않도록 nil로 넘긴다.
          #expect(savedSetIDs == nil)
          #expect(phase == .ongoing)
          #expect(start == startDate)
          #expect(end == endDate)
        },
        finish: { _, _ in },
        end: { _ in }
      )
    }

    await store.send(.inner(.liveActivityBoundary))
    await store.receive(\.inner.liveActivityUpdated) {
      $0.liveActivity.activities["other"] = .init(
        id: "activity-other",
        festivalID: "other",
        phase: .ongoing,
        startDate: startDate,
        endDate: endDate
      )
    }
    await store.send(.view(.foregroundChanged(false))) {
      $0.isForeground = false
    }
    await store.receive(\.async.prefetchImages)
    await store.finish()
  }

  @Test @MainActor func staleSnapshotReloadsAfterConcurrentStateChange() async {
    let now = Date(timeIntervalSince1970: 1_793_266_200)
    var state = FestivalFeature.State()
    state.liveActivity.isReady = true
    state.liveActivity.revision = 2
    state.liveActivity.activities["removed"] = .init(
      id: "old",
      festivalID: "removed",
      phase: .upcoming,
      startDate: now,
      endDate: nil
    )
    let store = TestStore(initialState: state) { FestivalFeature() } withDependencies: {
      $0.useServiceBackedFestivalUseCases()
      $0.date.now = now
      $0.festivalLiveActivityClient = .init(
        activities: { [] },
        changes: { AsyncStream { $0.finish() } },
        start: { _, _, _, _, _ in "unused" },
        update: { _, _, _, _, _, _ in },
        finish: { _, _ in },
        end: { _ in }
      )
    }

    await store.send(.inner(.liveActivitiesLoaded(
      [],
      1
    )))
    await store.receive(\.inner.liveActivitiesLoaded) {
      $0.liveActivity.now = now
      $0.liveActivity.activities = [:]
    }
    await store.finish()
  }

  @Test @MainActor func duplicateActivityForSameFestivalIsEnded() async {
    let now = ISO8601DateFormatter().date(from: "2026-10-29T09:30:00Z")!
    let start = ISO8601DateFormatter().date(from: "2026-10-29T09:00:00Z")!
    let end = ISO8601DateFormatter().date(from: "2026-10-30T09:00:00Z")!
    let ended = LockIsolated<[String]>([])
    let kept = FestivalLiveActivityRecord(
      id: "a-local",
      festivalID: "festival",
      phase: .ongoing,
      startDate: start,
      endDate: end
    )
    let pushStarted = FestivalLiveActivityRecord(
      id: "b-push",
      festivalID: "festival",
      phase: .ongoing,
      startDate: start,
      endDate: end
    )
    var state = FestivalFeature.State()
    state.hasStarted = true
    state.isForeground = false
    let store = TestStore(initialState: state) { FestivalFeature() } withDependencies: {
      $0.useServiceBackedFestivalUseCases()
      $0.date.now = now
      $0.festivalLiveActivityClient = .init(
        activities: { [] },
        changes: { AsyncStream { $0.finish() } },
        start: { _, _, _, _, _ in "unused" },
        update: { _, _, _, _, _, _ in },
        finish: { _, _ in },
        end: { id in ended.withValue { $0.append(id) } }
      )
    }

    await store.send(.inner(.liveActivitiesLoaded(
      [pushStarted, kept],
      0
    ))) {
      $0.liveActivity.isReady = true
      $0.liveActivity.now = now
      $0.liveActivity.activities = ["festival": kept]
    }
    await store.finish()
    #expect(ended.value == ["b-push"])
  }

  @Test @MainActor func finishingOtherFestivalKeepsCurrentOperationBusy() async {
    let now = ISO8601DateFormatter().date(from: "2026-10-29T09:30:00Z")!
    let oldStart = ISO8601DateFormatter().date(from: "2026-10-27T09:00:00Z")!
    let oldEnd = ISO8601DateFormatter().date(from: "2026-10-28T09:00:00Z")!
    let activeStart = ISO8601DateFormatter().date(from: "2026-10-29T09:00:00Z")!
    let activeEnd = ISO8601DateFormatter().date(from: "2026-10-30T09:00:00Z")!
    let clock = TestClock()
    var state = FestivalFeature.State()
    state.catalog = [
      festival(
        id: "ended",
        first: "2026-10-27T09:00:00Z",
        last: "2026-10-28T09:00:00Z"
      ),
      festival(id: "selected")
    ]
    state.selectedFestivalID = "selected"
    state.liveActivity.isReady = true
    state.hasStarted = true
    state.liveActivity.busyFestivalID = "selected"
    state.liveActivity.now = now
    state.liveActivity.activities["ended"] = .init(
      id: "ended-activity",
      festivalID: "ended",
      phase: .ongoing,
      startDate: oldStart,
      endDate: oldEnd
    )
    state.liveActivity.activities["selected"] = .init(
      id: "selected-activity",
      festivalID: "selected",
      phase: .ongoing,
      startDate: activeStart,
      endDate: activeEnd
    )
    let store = TestStore(initialState: state) { FestivalFeature() } withDependencies: {
      $0.useServiceBackedFestivalUseCases()
      $0.date.now = now
      $0.continuousClock = clock
      $0.festivalLiveActivityClient = .init(
        activities: { [] },
        changes: { AsyncStream { $0.finish() } },
        start: { _, _, _, _, _ in "unused" },
        update: { _, _, _, _, _, _ in },
        finish: { id, _ in #expect(id == "ended-activity") },
        end: { _ in }
      )
    }

    await store.send(.inner(.liveActivityBoundary))
    await store.receive(\.inner.liveActivityStopped) {
      $0.liveActivity.revision = 1
      $0.liveActivity.activities.removeValue(forKey: "ended")
    }
    #expect(store.state.liveActivity.busyFestivalID == "selected")
    await store.send(.view(.foregroundChanged(false))) {
      $0.isForeground = false
    }
    await store.receive(\.async.prefetchImages)
    await store.finish()
  }

  private func festival(
    id: String,
    first: String = "2026-10-29T09:00:00Z",
    last: String = "2026-10-30T09:00:00Z"
  ) -> FestivalCatalogItem {
    return FestivalCatalogItem(
      id: id,
      name: "축제",
      firstDate: first,
      lastDate: last,
      packVersion: 0
    )
  }

  private func savedPerformancePack() -> FestivalPackDocument {
    return try! JSONDecoder().decode(
      FestivalPackDocument.self,
      from: Data(
      #"{"id":"festival","sets":[{"id":"saved-set","startsAt":"2026-10-29T10:00:00Z","endsAt":"2026-10-29T11:00:00Z"}]}"#.utf8
    ))
  }
}
