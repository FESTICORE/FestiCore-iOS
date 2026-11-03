//
//  BearerStatusOutboxTests.swift
//  BearerDomainTests
//
//  Created by FestiCore on 11/3/26.
//

import BearerDomainInterface
import Dependencies
import Foundation
import Testing
@testable import BearerDomain

@Suite("기수 상태 대기열")
struct BearerStatusOutboxTests {
  private let now = Date(timeIntervalSince1970: 1_800_000_000)

  private func request(_ change: BearerStatusChange, _ key: String, offset: TimeInterval = 0) -> BearerStatusRequest {
    BearerStatusRequest(change: change, idempotencyKey: key, clientAt: now.addingTimeInterval(offset))
  }

  private var resting: BearerFlagStatus {
    BearerFlagStatus(flagID: "flg_1", lifecycle: .resting, zoneID: "zone_a", activity: nil, updatedAt: now)
  }

  private func makeOutbox(
    _ repository: ScriptedRepository,
    auth: StubAuthService = StubAuthService(),
    clock: any Clock<Duration> = ImmediateClock(),
    fileURL: URL? = nil
  ) -> BearerStatusOutboxImpl {
    withDependencies {
      $0.bearerRepository = repository
      $0.authService = auth
      $0.continuousClock = clock
    } operation: {
      BearerStatusOutboxImpl(fileURL: fileURL)
    }
  }

  @Test("동시에 들어온 변경도 누른 시각 순서대로 보낸다")
  func ordersConcurrentEnqueues() async {
    let auth = StubAuthService()
    await auth.hold()
    let repository = ScriptedRepository(Array(repeating: .success(resting), count: 5))
    let outbox = makeOutbox(repository, auth: auth)
    let events = await outbox.events(flagID: "flg_1")

    await withTaskGroup(of: Void.self) { group in
      for index in [3, 0, 4, 1, 2] {
        group.addTask { await outbox.enqueue(flagID: "flg_1", ownerUserID: "usr_me", request: request(.rest, "key-\(index)", offset: Double(index))) }
      }
    }
    await auth.release()
    _ = await collect(events) { $0 == .pending([]) }

    #expect(await repository.sentKeys == ["key-0", "key-1", "key-2", "key-3", "key-4"])
  }

  @Test("연결이 없으면 남겨 두고 5초 뒤 같은 멱등키로 다시 보낸다")
  func retriesOffline() async {
    let clock = TestClock()
    let repository = ScriptedRepository([.failure(.offline), .success(resting)])
    let outbox = makeOutbox(repository, clock: clock)
    let events = await outbox.events(flagID: "flg_1")

    await outbox.enqueue(flagID: "flg_1", ownerUserID: "usr_me", request: request(.rest, "key-1"))
    _ = await collect(events) { $0 == .offline }
    await clock.advance(by: .seconds(5))
    _ = await collect(events) { $0 == .pending([]) }

    #expect(await repository.sentKeys == ["key-1", "key-1"])
  }

  @Test("429면 15초 기다렸다가 다시 보낸다")
  func retriesRateLimited() async {
    let clock = TestClock()
    let repository = ScriptedRepository([.failure(.rateLimited), .success(resting)])
    let outbox = makeOutbox(repository, clock: clock)
    let events = await outbox.events(flagID: "flg_1")

    await outbox.enqueue(flagID: "flg_1", ownerUserID: "usr_me", request: request(.rest, "key-1"))
    await Task.megaYield()
    await clock.advance(by: .seconds(14))
    #expect(await repository.sentKeys == ["key-1"])
    await clock.advance(by: .seconds(1))
    _ = await collect(events) { $0 == .pending([]) }
    #expect(await repository.sentKeys == ["key-1", "key-1"])
  }

  @Test("401이면 대기열을 남기고 멈췄다가 다시 시작하면 이어서 보낸다")
  func keepsQueueOnUnauthorized() async {
    let repository = ScriptedRepository([.failure(.notAuthenticated), .success(resting)])
    let outbox = makeOutbox(repository)
    let events = await outbox.events(flagID: "flg_1")

    await outbox.enqueue(flagID: "flg_1", ownerUserID: "usr_me", request: request(.rest, "key-1"))
    _ = await collect(events) { $0 == .needsLogin }
    #expect(await outbox.pending(flagID: "flg_1").count == 1)

    await outbox.resume()
    _ = await collect(events) { $0 == .pending([]) }
    #expect(await repository.sentKeys == ["key-1", "key-1"])
  }

  @Test("서버 오류는 2·4·8·16·32초 뒤 다시 보내고 그 뒤 멈추며 대기열은 남긴다")
  func backsOffThenGivesUp() async {
    let clock = TestClock()
    let failures = Array(repeating: Result<BearerFlagStatus, BearerError>.failure(.unavailable), count: 10)
    let repository = ScriptedRepository(failures)
    let outbox = makeOutbox(repository, clock: clock)
    let events = await outbox.events(flagID: "flg_1")

    await outbox.enqueue(flagID: "flg_1", ownerUserID: "usr_me", request: request(.rest, "key-1"))
    await Task.megaYield()
    for (attempt, delay) in [2, 4, 8, 16, 32].enumerated() {
      #expect(await repository.sentKeys.count == attempt + 1)
      await clock.advance(by: .seconds(delay - 1))
      #expect(await repository.sentKeys.count == attempt + 1)
      await clock.advance(by: .seconds(1))
      await Task.megaYield()
    }
    let received = await collect(events) { if case .gaveUp = $0 { return true } else { return false } }

    #expect(received.last == .gaveUp(.unavailable))
    #expect(await repository.sentKeys.count == BearerStatusOutboxImpl.maxServerRetries + 1)
    #expect(await outbox.pending(flagID: "flg_1").count == 1)
  }

  @Test("약관 동의가 필요하면 대기열을 남기고 멈춘다")
  func keepsQueueOnTermsRequired() async {
    let outbox = makeOutbox(ScriptedRepository([.failure(.termsRequired)]))
    let events = await outbox.events(flagID: "flg_1")

    await outbox.enqueue(flagID: "flg_1", ownerUserID: "usr_me", request: request(.rest, "key-1"))
    _ = await collect(events) { $0 == .gaveUp(.termsRequired) }

    #expect(await outbox.pending(flagID: "flg_1").count == 1)
  }

  @Test("서버가 받지 않는 변경이면 그 깃발의 대기열을 비운다")
  func dropsRejected() async {
    let auth = StubAuthService()
    await auth.hold()
    let repository = ScriptedRepository([.failure(.stale)])
    let outbox = makeOutbox(repository, auth: auth)
    let events = await outbox.events(flagID: "flg_1")

    await outbox.enqueue(flagID: "flg_1", ownerUserID: "usr_me", request: request(.rest, "key-1"))
    await outbox.enqueue(flagID: "flg_1", ownerUserID: "usr_me", request: request(.end, "key-2", offset: 1))
    await auth.release()
    _ = await collect(events) { $0 == .rejected(.stale) }

    #expect(await repository.sentKeys == ["key-1"])
    #expect(await outbox.pending(flagID: "flg_1").isEmpty)
  }

  @Test("다른 계정으로 바뀌면 이전 계정의 대기열을 보내지 않고 버린다")
  func dropsOtherAccount() async {
    let repository = ScriptedRepository([])
    let outbox = makeOutbox(repository, auth: StubAuthService(userID: "usr_b"))
    let events = await outbox.events(flagID: "flg_1")

    await outbox.enqueue(flagID: "flg_1", ownerUserID: "usr_a", request: request(.rest, "key-1"))
    _ = await collect(events) { $0 == .pending([]) }

    #expect(await repository.sentKeys.isEmpty)
  }

  @Test("앱을 다시 켜도 남긴 대기열을 읽고, 사용자를 모르는 기록은 버린다")
  func persists() async throws {
    let url = FileManager.default.temporaryDirectory.appendingPathComponent("outbox-\(UUID().uuidString).json")
    defer { try? FileManager.default.removeItem(at: url) }
    let restart = request(.restart(zoneID: "zone_a", activity: .sing), "key-1")
    let first = makeOutbox(ScriptedRepository([]), auth: StubAuthService(userID: nil), fileURL: url)
    await first.enqueue(flagID: "flg_1", ownerUserID: "usr_me", request: restart)

    let second = makeOutbox(ScriptedRepository([]), auth: StubAuthService(userID: nil), fileURL: url)
    #expect(await second.pending(flagID: "flg_1").isEmpty)
    let third = makeOutbox(ScriptedRepository([]), fileURL: url)
    #expect(await third.pending(flagID: "flg_1") == [restart])

    let legacy = #"[{"flagID":"flg_1","idempotencyKey":"k","clientAt":0,"kind":"rest"}]"#
    try Data(legacy.utf8).write(to: url)
    #expect(await makeOutbox(ScriptedRepository([]), fileURL: url).pending(flagID: "flg_1").isEmpty)
  }

  /// 조건에 맞는 이벤트가 올 때까지 모은다. 2초 안에 오지 않으면 실패로 남기고 끝낸다.
  private func collect(
    _ stream: AsyncStream<BearerOutboxEvent>,
    until done: @escaping @Sendable (BearerOutboxEvent) -> Bool
  ) async -> [BearerOutboxEvent] {
    await withTaskGroup(of: [BearerOutboxEvent]?.self) { group in
      group.addTask {
        var received: [BearerOutboxEvent] = []
        for await event in stream {
          received.append(event)
          if done(event) { return received }
        }
        return received
      }
      group.addTask {
        try? await Task.sleep(for: .seconds(2))
        return nil
      }
      let first = await group.next() ?? nil
      group.cancelAll()
      if first == nil { Issue.record("기다린 대기열 이벤트가 오지 않았다") }
      return first ?? []
    }
  }
}

private actor ScriptedRepository: BearerRepositoryInterface {
  private var results: [Result<BearerFlagStatus, BearerError>]
  private(set) var sentKeys: [String] = []

  init(_ results: [Result<BearerFlagStatus, BearerError>]) {
    self.results = results
  }

  func sendStatus(flagID: String, request: BearerStatusRequest) async throws -> BearerFlagStatus {
    sentKeys.append(request.idempotencyKey)
    guard !results.isEmpty else { throw BearerError.notAuthenticated }
    return try results.removeFirst().get()
  }

  func claim(festivalID: String, code: String) async throws -> BearerClaim { throw BearerError.unavailable }
  func fetchBoard(flagID: String) async throws -> BearerBoard { throw BearerError.unavailable }
  func updateProfile(flagID: String, change: BearerProfileChange) async throws -> BearerFlagProfile { throw BearerError.unavailable }
  func uploadPhoto(flagID: String, jpegData: Data, progress: @escaping @Sendable (Double) -> Void) async throws -> BearerFlagPhoto {
    throw BearerError.unavailable
  }
  func inviteCoBearer(flagID: String) async throws -> BearerInvite { throw BearerError.unavailable }
  func removeCoBearer(flagID: String, userID: String) async throws { throw BearerError.unavailable }
}
