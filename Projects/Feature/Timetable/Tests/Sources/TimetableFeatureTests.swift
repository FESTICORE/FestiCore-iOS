import ComposableArchitecture
import Testing
@testable import Timetable

@MainActor
struct TimetableFeatureTests {
  @Test func tappingSetOpensDetailWithoutChangingSchedule() async {
    let store = TestStore(initialState: TimetableFeature.State.sample()) {
      TimetableFeature()
    }

    await store.send(.view(.setTapped("lime"))) {
      $0.selectedSetID = "lime"
    }
    await store.send(.view(.setDetailDismissed)) {
      $0.selectedSetID = nil
    }
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

  @Test func timeTextsMatchDesign() {
    #expect(TimetableTime.range(1410, 1530) == "23:30–다음날 01:30")
    #expect(TimetableTime.range(750, 790) == "12:30–13:10")
    #expect(TimetableTime.change(from: 1000, to: 1020) == "20분 미뤄짐")
    #expect(TimetableTime.change(from: 1105, to: 1090) == "15분 당겨짐")
  }

  @Test func unpublishedStateShowsLineup() {
    let state = TimetableFeature.State.sample(variant: .unpublished)

    #expect(!state.isPublished)
    #expect(state.lineup.map(\.artists.count) == [5, 4])
  }
}
