import Clocks
import ComposableArchitecture
import FestivalDomainInterface
import Foundation
import Testing
@testable import Home

struct HomeLiveActivityTests {
  @Test @MainActor func startIsDisabledUntilOSActivitiesAreRestored() async {
    var state = HomeFeature.State()
    state.catalog = [festival(id: "festival")]
    state.selectedFestivalID = "festival"
    let store = TestStore(initialState: state) { HomeFeature() }

    await store.send(.view(.liveActivityTapped))
    #expect(!store.state.liveActivityState.isEnabled)
    await store.finish()
  }

  @Test @MainActor func successfulStartCanBeStoppedByUser() async {
    let now = Date(timeIntervalSince1970: 1_793_266_200)
    let startDate = ISO8601DateFormatter().date(from: "2026-10-29T09:00:00Z")!
    let endDate = ISO8601DateFormatter().date(from: "2026-10-30T09:00:00Z")!
    let clock = TestClock()
    var state = HomeFeature.State()
    state.catalog = [festival(id: "festival")]
    state.selectedFestivalID = "festival"
    state.liveActivityReady = true
    state.liveActivityNow = now
    let store = TestStore(initialState: state) { HomeFeature() } withDependencies: {
      $0.date.now = now
      $0.continuousClock = clock
      $0.homeLiveActivityClient = .init(
        activities: { [] },
        changes: { AsyncStream { $0.finish() } },
        start: { _, _, _, _, _ in "activity" },
        update: { _, _, _, _ in },
        finish: { _, _ in },
        end: { _ in }
      )
    }

    await store.send(.view(.liveActivityTapped)) {
      $0.liveActivityBusyFestivalID = "festival"
      $0.liveActivityRevision = 1
    }
    await store.receive(\.inner.liveActivityStarted) {
      $0.liveActivityBusyFestivalID = nil
      $0.liveActivityRevision = 2
      $0.liveActivities["festival"] = .init(
        id: "activity", festivalID: "festival", phase: .ongoing,
        startDate: startDate, endDate: endDate
      )
    }
    #expect(store.state.liveActivityState.title == "Live Activity 끄기")
    await store.send(.view(.liveActivityTapped)) {
      $0.liveActivityBusyFestivalID = "festival"
      $0.liveActivityRevision = 3
    }
    await store.receive(\.inner.liveActivityStopped) {
      $0.liveActivityBusyFestivalID = nil
      $0.liveActivityRevision = 4
      $0.liveActivities = [:]
    }
    await store.send(.view(.foregroundChanged(false))) {
      $0.isForeground = false
    }
    await store.finish()
  }

  @Test @MainActor func nonSelectedFestivalReceivesScheduleUpdate() async {
    let now = ISO8601DateFormatter().date(from: "2026-10-29T09:30:00Z")!
    let oldStart = now.addingTimeInterval(-7_200)
    let startDate = ISO8601DateFormatter().date(from: "2026-10-29T09:00:00Z")!
    let endDate = ISO8601DateFormatter().date(from: "2026-10-30T09:00:00Z")!
    let clock = TestClock()
    var state = HomeFeature.State()
    state.catalog = [festival(id: "selected"), festival(id: "other")]
    state.selectedFestivalID = "selected"
    state.liveActivityReady = true
    state.liveActivityNow = now
    state.liveActivities["other"] = .init(
      id: "activity-other", festivalID: "other", phase: .ongoing,
      startDate: oldStart, endDate: endDate
    )
    let store = TestStore(initialState: state) { HomeFeature() } withDependencies: {
      $0.date.now = now
      $0.continuousClock = clock
      $0.homeLiveActivityClient = .init(
        activities: { [] },
        changes: { AsyncStream { $0.finish() } },
        start: { _, _, _, _, _ in "unused" },
        update: { id, phase, start, end in
          #expect(id == "activity-other")
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
      $0.liveActivities["other"] = .init(
        id: "activity-other", festivalID: "other", phase: .ongoing,
        startDate: startDate, endDate: endDate
      )
    }
    await store.send(.view(.foregroundChanged(false))) {
      $0.isForeground = false
    }
    await store.finish()
  }

  private func festival(id: String) -> FestivalCatalogItem {
    FestivalCatalogItem(
      id: id,
      name: "축제",
      firstDate: "2026-10-29T09:00:00Z",
      lastDate: "2026-10-30T09:00:00Z",
      packVersion: 0
    )
  }
}
