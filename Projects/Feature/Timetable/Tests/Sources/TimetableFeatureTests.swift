import ComposableArchitecture
import Foundation
import Testing
import TimetableDomainInterface
@testable import Timetable

@MainActor
struct TimetableFeatureTests {
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
