import ActivityKit
import FestiCoreDeviceInterface
import FestiCoreLiveActivity
import FestiCoreNetworkInterface
import Foundation
import Testing
@testable import FestiCore

@MainActor
struct LiveActivityTokenSyncTests {
  @Test("복원된 Activity의 토큰과 교체 토큰을 등록하고 종료 시 해제한다")
  func restoresRotatesAndRemoves() async {
    let source = TestActivitySource(summaries: [summary(id: "activity-a", festivalID: "festival-a")])
    let service = RecordingLiveActivityService()
    let sync = makeSync(source: source, service: service)
    sync.start()
    defer { sync.stop() }

    #expect(await waitFor { source.isObserving("activity-a") })
    source.emitToken(id: "activity-a", festivalID: "festival-a", value: "token-a")
    #expect(await waitFor { await service.operations.contains(.register("activity-a", "token-a")) })

    source.emitToken(id: "activity-a", festivalID: "festival-a", value: "token-b")
    #expect(await waitFor { await service.operations.contains(.register("activity-a", "token-b")) })

    source.summaries = []
    source.emitChange()
    #expect(await waitFor { await service.operations.last == .remove })
  }

  @Test("새로 시작된 Activity를 관찰하고 기기당 현재 Activity 하나만 등록한다")
  func observesNewActivityAndSelectsOne() async {
    let source = TestActivitySource(summaries: [])
    let service = RecordingLiveActivityService()
    let sync = makeSync(source: source, service: service)
    sync.start()
    defer { sync.stop() }

    source.summaries = [
      summary(id: "activity-b", festivalID: "festival-b", startOffset: 60),
      summary(id: "activity-a", festivalID: "festival-a")
    ]
    source.emitChange()
    #expect(await waitFor { source.isObserving("activity-b") })
    #expect(!source.isObserving("activity-a"))
    source.emitToken(id: "activity-b", festivalID: "festival-b", value: "token-b")
    #expect(await waitFor { await service.operations.contains(.register("activity-b", "token-b")) })

    source.summaries.removeAll { $0.id == "activity-b" }
    source.emitChange()
    #expect(await waitFor { source.isObserving("activity-a") })
    source.emitToken(id: "activity-a", festivalID: "festival-a", value: "token-a")
    #expect(await waitFor { await service.operations.last == .register("activity-a", "token-a") })
  }

  @Test("기존 stale Activity 대신 새 active Activity의 업데이트 토큰을 등록한다")
  func selectsActiveOverStaleActivity() async {
    let source = TestActivitySource(summaries: [
      summary(id: "activity-a", festivalID: "festival-a", state: .stale)
    ])
    let service = RecordingLiveActivityService()
    let sync = makeSync(source: source, service: service)
    sync.start()
    defer { sync.stop() }

    #expect(await waitFor { source.isObserving("activity-a") })
    source.emitToken(id: "activity-a", festivalID: "festival-a", value: "stale-token")
    #expect(await waitFor { await service.operations.last == .register("activity-a", "stale-token") })

    source.summaries.append(summary(id: "activity-b", festivalID: "festival-b", startOffset: 60))
    source.emitChange()
    #expect(await waitFor { source.isObserving("activity-b") })
    source.emitToken(id: "activity-a", festivalID: "festival-a", value: "ignored-token")
    source.emitToken(id: "activity-b", festivalID: "festival-b", value: "active-token")
    #expect(await waitFor { await service.operations.last == .register("activity-b", "active-token") })
    #expect(!(await service.operations).contains(.register("activity-a", "ignored-token")))
  }

  @Test("일시적인 등록 실패 후 같은 토큰을 재시도한다")
  func retriesFailedRegistration() async {
    let source = TestActivitySource(summaries: [summary(id: "activity-a", festivalID: "festival-a")])
    let service = RecordingLiveActivityService(failuresRemaining: 1)
    let sync = makeSync(source: source, service: service)
    sync.start()
    defer { sync.stop() }

    #expect(await waitFor { source.isObserving("activity-a") })
    source.emitToken(id: "activity-a", festivalID: "festival-a", value: "token-a")
    #expect(await waitFor { await service.operations == [.register("activity-a", "token-a")] })
    #expect(await service.registerAttempts == 2)
  }

  private func makeSync(
    source: TestActivitySource,
    service: RecordingLiveActivityService
  ) -> LiveActivityTokenSync {
    LiveActivityTokenSync(
      source: source.client,
      authorization: { DeviceAuthorization(deviceID: "device-id", bearerToken: "device-token") },
      registrationService: service
    )
  }

  private func summary(
    id: String,
    festivalID: String,
    state: ActivityState = .active,
    startOffset: TimeInterval = 0
  ) -> FestiCoreFestivalActivitySummary {
    FestiCoreFestivalActivitySummary(
      id: id,
      festivalID: festivalID,
      state: state,
      phase: .upcoming,
      startDate: Date(timeIntervalSince1970: 1_000 + startOffset),
      endDate: nil
    )
  }

  private func waitFor(_ condition: () async -> Bool) async -> Bool {
    for _ in 0..<175 {
      if await condition() { return true }
      try? await Task.sleep(for: .milliseconds(20))
    }
    return await condition()
  }
}

@MainActor
private final class TestActivitySource {
  var summaries: [FestiCoreFestivalActivitySummary]
  private let changes = AsyncStream<Void>.makeStream()
  private var tokens: [String: AsyncStream<FestiCoreFestivalPushToken>.Continuation] = [:]

  init(summaries: [FestiCoreFestivalActivitySummary]) {
    self.summaries = summaries
  }

  var client: LiveActivityTokenSync.Source {
    .init(
      activities: { self.summaries },
      changes: { self.changes.stream },
      pushTokenUpdates: { id in
        let updates = AsyncStream<FestiCoreFestivalPushToken>.makeStream()
        self.tokens[id] = updates.continuation
        return updates.stream
      }
    )
  }

  func isObserving(_ id: String) -> Bool { tokens[id] != nil }
  func emitChange() { changes.continuation.yield() }
  func emitToken(id: String, festivalID: String, value: String) {
    tokens[id]?.yield(.init(festivalID: festivalID, activityID: id, value: value))
  }
}

private enum LiveActivityOperation: Equatable, Sendable {
  case register(String, String)
  case remove
}

private actor RecordingLiveActivityService: LiveActivityRegistrationService {
  private(set) var operations: [LiveActivityOperation] = []
  private(set) var registerAttempts = 0
  private var failuresRemaining: Int

  init(failuresRemaining: Int = 0) {
    self.failuresRemaining = failuresRemaining
  }

  func register(
    _ registration: LiveActivityRegistration,
    authorization _: DeviceAuthorization
  ) async throws(FestiCoreNetworkError) {
    registerAttempts += 1
    if failuresRemaining > 0 {
      failuresRemaining -= 1
      throw .response(ResponseError(httpStatus: 503))
    }
    operations.append(.register(registration.activityID, registration.pushToken))
  }

  func remove(authorization _: DeviceAuthorization) async throws(FestiCoreNetworkError) {
    operations.append(.remove)
  }
}
