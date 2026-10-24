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

    // 위젯이 잠금 화면에 그려질 시간을 확보한다.
    try await Task.sleep(for: .seconds(10))

    await FestiCoreFestivalLiveActivity.end(id: id)
    #expect(!Activity<FestiCoreFestivalActivityAttributes>.activities.contains { $0.id == id })
  }
}
