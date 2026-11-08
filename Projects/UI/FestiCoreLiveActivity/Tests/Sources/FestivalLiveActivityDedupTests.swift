import ActivityKit
import Foundation
import Testing
@testable import FestiCoreLiveActivity

struct FestivalLiveActivityDedupTests {
  @Test("같은 축제 활동이 둘이면 하나만 남기고 나머지를 중복으로 돌려준다")
  func keepsOneActivityPerFestival() {
    let partition = FestiCoreFestivalLiveActivity.partitionDuplicates([
      summary(
        id: "push-started",
        festivalID: "festival-a"
      ),
      summary(
        id: "local-started",
        festivalID: "festival-a"
      ),
      summary(
        id: "other-festival",
        festivalID: "festival-b"
      )
    ])

    #expect(partition.kept.map(\.id) == ["local-started", "other-festival"])
    #expect(partition.duplicates.map(\.id) == ["push-started"])
  }

  @Test("입력 순서가 달라도 같은 활동을 남긴다")
  func keepsSameActivityRegardlessOfOrder() {
    let activities = [
      summary(
        id: "activity-b",
        festivalID: "festival-a"
      ),
      summary(
        id: "activity-a",
        festivalID: "festival-a"
      ),
      summary(
        id: "activity-c",
        festivalID: "festival-a"
      )
    ]

    let forward = FestiCoreFestivalLiveActivity.partitionDuplicates(activities)
    let reversed = FestiCoreFestivalLiveActivity.partitionDuplicates(activities.reversed())

    #expect(forward.kept.map(\.id) == ["activity-a"])
    #expect(reversed.kept.map(\.id) == ["activity-a"])
    #expect(Set(forward.duplicates.map(\.id)) == ["activity-b", "activity-c"])
  }

  @Test("stale 활동보다 active 활동을 남긴다")
  func prefersActiveOverStale() {
    let partition = FestiCoreFestivalLiveActivity.partitionDuplicates([
      summary(
        id: "activity-a",
        festivalID: "festival-a",
        state: .stale
      ),
      summary(
        id: "activity-b",
        festivalID: "festival-a"
      )
    ])

    #expect(partition.kept.map(\.id) == ["activity-b"])
    #expect(partition.duplicates.map(\.id) == ["activity-a"])
  }

  @Test("축제마다 활동이 하나면 중복이 없다")
  func reportsNoDuplicatesForDistinctFestivals() {
    let partition = FestiCoreFestivalLiveActivity.partitionDuplicates([
      summary(
        id: "activity-a",
        festivalID: "festival-a"
      ),
      summary(
        id: "activity-b",
        festivalID: "festival-b"
      )
    ])

    #expect(partition.kept.count == 2)
    #expect(partition.duplicates.isEmpty)
  }
}

private extension FestivalLiveActivityDedupTests {
  func summary(
    id: String,
    festivalID: String,
    state: ActivityState = .active
  ) -> FestiCoreFestivalActivitySummary {
    return FestiCoreFestivalActivitySummary(
      id: id,
      festivalID: festivalID,
      state: state,
      phase: .upcoming,
      startDate: Date(timeIntervalSince1970: 1_000),
      endDate: nil
    )
  }
}
