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
import UIKit

@Suite("Live Activity 통합", .serialized)
struct LiveActivityIntegrationTests {
  @Test("앱에서 Live Activity를 시작하고 종료한다")
  func startsAndEndsOnDevice() async throws {
    #expect(ActivityAuthorizationInfo().areActivitiesEnabled)
    guard await waitUntilAppIsActive() else { return }

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
    let updated = await waitFor {
      FestiCoreFestivalLiveActivity.activities().contains {
        $0.id == id && $0.phase == .ongoing
      }
    }
    #expect(updated)

    // 위젯이 잠금 화면에 그려질 시간을 확보한다.
    try await Task.sleep(for: .seconds(10))

    await FestiCoreFestivalLiveActivity.end(id: id)
    let ended = await waitFor {
      !Activity<FestiCoreFestivalActivityAttributes>.activities.contains { $0.id == id }
    }
    #expect(ended)
    #expect(!FestiCoreFestivalLiveActivity.activities().contains { $0.id == id })
  }

  @Test("축제가 끝나면 완료 상태로 종료한다")
  func endsWithFinishedContent() async throws {
    #expect(ActivityAuthorizationInfo().areActivitiesEnabled)
    guard await waitUntilAppIsActive() else { return }

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

    let ended = await waitFor {
      activity.activityState == .ended && activity.content.state.phase == .finished
    }
    #expect(ended)
    #expect(!FestiCoreFestivalLiveActivity.activities().contains { $0.id == id })
  }

  private func waitFor(_ condition: () -> Bool) async -> Bool {
    let deadline = Date().addingTimeInterval(8)
    while Date() < deadline {
      if condition() { return true }
      try? await Task.sleep(for: .milliseconds(100))
    }
    return condition()
  }

  @MainActor
  private func waitUntilAppIsActive() async -> Bool {
    let app = UIApplication.shared
    var requested = false
    var activationError: String?
    let deadline = Date().addingTimeInterval(8)
    while Date() < deadline {
      if app.applicationState == .active { return true }
      if !requested {
        requested = true
        let scene = app.connectedScenes.compactMap { $0 as? UIWindowScene }
          .first(where: { $0.session.role == .windowApplication })
        let request: UISceneSessionActivationRequest = if let scene {
          .init(session: scene.session)
        } else {
          .init(role: .windowApplication)
        }
        app.activateSceneSession(for: request) { error in
          activationError = error.localizedDescription
        }
      }
      if activationError != nil { break }
      try? await Task.sleep(for: .milliseconds(100))
    }
    if app.applicationState == .active { return true }
    let scenes = app.connectedScenes.map { String(describing: $0.activationState) }.joined(separator: ", ")
    let message = "Live Activity 시작 전 앱 활성화 실패: state=\(app.applicationState), sceneStates=[\(scenes)], requested=\(requested), error=\(activationError ?? "없음")"
    print(message)
    Issue.record("\(message)")
    return false
  }
}
