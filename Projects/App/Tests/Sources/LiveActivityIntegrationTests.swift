//
//  LiveActivityIntegrationTests.swift
//  FestiCore
//
//  Created by FestiCore on 10/25/26.
//

import ActivityKit
import FestiCoreLiveActivity
import Foundation
import Testing

struct LiveActivityIntegrationTests {
  @Test("앱에서 Live Activity를 시작하고 종료한다")
  func startsAndEndsOnDevice() async throws {
    #expect(ActivityAuthorizationInfo().areActivitiesEnabled)

    let festivalID = UUID().uuidString
    let id = try FestiCoreFestivalLiveActivity.start(
      festivalID: festivalID,
      festivalName: "FestiCore 테스트",
      startDate: Date().addingTimeInterval(3_600)
    )

    #expect(Activity<FestiCoreFestivalActivityAttributes>.activities.contains { $0.id == id })
    #expect(FestiCoreFestivalLiveActivity.activities().contains {
      $0.id == id && $0.festivalID == festivalID && $0.phase == .upcoming
    })

    let duplicateID = try FestiCoreFestivalLiveActivity.start(
      festivalID: festivalID,
      festivalName: "FestiCore 테스트",
      startDate: Date().addingTimeInterval(3_600)
    )
    #expect(duplicateID == id)

    await FestiCoreFestivalLiveActivity.update(id: id, phase: .ongoing, startDate: Date())
    #expect(FestiCoreFestivalLiveActivity.activities().contains {
      $0.id == id && $0.phase == .ongoing
    })

    // 위젯이 잠금 화면에 그려질 시간을 확보한다.
    try await Task.sleep(for: .seconds(10))

    await FestiCoreFestivalLiveActivity.end(id: id)
    #expect(!Activity<FestiCoreFestivalActivityAttributes>.activities.contains { $0.id == id })
    #expect(!FestiCoreFestivalLiveActivity.activities().contains { $0.id == id })
  }

  @Test("축제가 끝나면 완료 상태로 종료한다")
  func endsWithFinishedContent() async throws {
    #expect(ActivityAuthorizationInfo().areActivitiesEnabled)

    let startDate = Date().addingTimeInterval(-3_600)
    let endDate = Date().addingTimeInterval(3_600)
    let id = try FestiCoreFestivalLiveActivity.start(
      festivalID: UUID().uuidString,
      festivalName: "FestiCore 종료 테스트",
      startDate: startDate,
      phase: .ongoing,
      endDate: endDate
    )
    let activity = try #require(
      Activity<FestiCoreFestivalActivityAttributes>.activities.first(where: { $0.id == id })
    )
    #expect(abs((activity.content.staleDate ?? .distantPast).timeIntervalSince(endDate)) < 1)

    await FestiCoreFestivalLiveActivity.endFinished(id: id, startDate: startDate)

    #expect(activity.activityState == .ended)
    #expect(activity.content.state.phase == .finished)
    #expect(!FestiCoreFestivalLiveActivity.activities().contains { $0.id == id })
  }
}
