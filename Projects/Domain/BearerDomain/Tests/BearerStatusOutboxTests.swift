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
    _ repository: any BearerRepositoryInterface,
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
    let clock = RecordingClock()
    let repository = ScriptedRepository([.failure(.offline), .success(resting)])
    let outbox = makeOutbox(repository, clock: clock)
    let events = await outbox.events(flagID: "flg_1")

    await outbox.enqueue(flagID: "flg_1", ownerUserID: "usr_me", request: request(.rest, "key-1"))
    _ = await collect(events) { $0 == .pending([]) }

    #expect(await repository.sentKeys == ["key-1", "key-1"])
    #expect(clock.sleeps == [.seconds(5)])
  }

  @Test("429면 15초 기다렸다가 다시 보낸다")
  func retriesRateLimited() async {
    let clock = RecordingClock()
    let repository = ScriptedRepository([.failure(.rateLimited), .success(resting)])
    let outbox = makeOutbox(repository, clock: clock)
    let events = await outbox.events(flagID: "flg_1")

    await outbox.enqueue(flagID: "flg_1", ownerUserID: "usr_me", request: request(.rest, "key-1"))
    _ = await collect(events) { $0 == .pending([]) }

    #expect(await repository.sentKeys == ["key-1", "key-1"])
    #expect(clock.sleeps == [.seconds(15)])
  }

  @Test("한 번 보내 본 건은 재시도 전이라도 그 앞에 더 이른 변경을 끼워 넣지 않는다")
  func keepsAttemptedItemFirst() async {
    let auth = StubAuthService()
    let repository = GatedRepository([.failure(.offline), .success(resting), .success(resting)])
    let outbox = makeOutbox(repository, auth: auth, clock: RecordingClock())
    let events = await outbox.events(flagID: "flg_1")

    await outbox.enqueue(flagID: "flg_1", ownerUserID: "usr_me", request: request(.rest, "late", offset: 10))
    await waitUntil { await repository.sentKeys.count == 1 }
    // 첫 시도가 실패하고 재시도 전 사용자 확인에서 멈춘 사이(보내는 중이 아닐 때) 더 이른 변경이 들어온다.
    await auth.hold()
    await repository.release()
    await waitUntil { await auth.waiterCount == 1 }
    await outbox.enqueue(flagID: "flg_1", ownerUserID: "usr_me", request: request(.end, "early"))
    await auth.release()
    await repository.release()
    await repository.release()
    _ = await collect(events) { $0 == .pending([]) }

    #expect(await repository.sentKeys == ["late", "late", "early"])
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
    let clock = RecordingClock()
    let failures = Array(repeating: Result<BearerFlagStatus, BearerError>.failure(.unavailable), count: 10)
    let repository = ScriptedRepository(failures)
    let outbox = makeOutbox(repository, clock: clock)
    let events = await outbox.events(flagID: "flg_1")

    await outbox.enqueue(flagID: "flg_1", ownerUserID: "usr_me", request: request(.rest, "key-1"))
    let received = await collect(events) { if case .gaveUp = $0 { return true } else { return false } }

    #expect(received.last == .gaveUp(.unavailable))
    #expect(clock.sleeps == [2, 4, 8, 16, 32].map { .seconds($0) })
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

  /// 조건이 맞을 때까지 잠깐씩 기다린다. 2초 안에 맞지 않으면 실패로 남긴다.
  private func waitUntil(_ condition: @Sendable () async -> Bool) async {
    for _ in 0 ..< 200 {
      if await condition() { return }
      try? await Task.sleep(for: .milliseconds(10))
    }
    Issue.record("기다린 조건이 맞지 않았다")
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
  func register(_ request: BearerRegisterRequest) async throws -> BearerClaim { throw BearerError.unavailable }
  func fetchBearerFlags(festivalID: String?) async throws -> [BearerOwnedFlag] { throw BearerError.unavailable }
  func fetchPinnedFlag() async throws -> BearerPinnedFlag? { throw BearerError.unavailable }
}

/// 기다리지 않고 요청한 대기 시간만 기록하는 시계
private final class RecordingClock: Clock, @unchecked Sendable {
  struct Instant: InstantProtocol {
    var offset: Duration
    func advanced(by duration: Duration) -> Instant { Instant(offset: offset + duration) }
    func duration(to other: Instant) -> Duration { other.offset - offset }
    static func < (lhs: Instant, rhs: Instant) -> Bool { lhs.offset < rhs.offset }
  }

  private let state = LockIsolated((now: Instant(offset: .zero), sleeps: [Duration]()))
  var now: Instant { state.value.now }
  var minimumResolution: Duration { .zero }
  var sleeps: [Duration] { state.value.sleeps }

  func sleep(until deadline: Instant, tolerance: Duration?) async throws {
    try Task.checkCancellation()
    state.withValue {
      $0.sleeps.append($0.now.duration(to: deadline))
      $0.now = deadline
    }
  }
}

/// 전송마다 release를 기다리는 저장소
private actor GatedRepository: BearerRepositoryInterface {
  private var results: [Result<BearerFlagStatus, BearerError>]
  private var waiters: [CheckedContinuation<Void, Never>] = []
  private var permits = 0
  private(set) var sentKeys: [String] = []

  init(_ results: [Result<BearerFlagStatus, BearerError>]) {
    self.results = results
  }

  func release() {
    if waiters.isEmpty { permits += 1 } else { waiters.removeFirst().resume() }
  }

  func sendStatus(flagID: String, request: BearerStatusRequest) async throws -> BearerFlagStatus {
    sentKeys.append(request.idempotencyKey)
    if permits > 0 {
      permits -= 1
    } else {
      await withCheckedContinuation { waiters.append($0) }
    }
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
  func register(_ request: BearerRegisterRequest) async throws -> BearerClaim { throw BearerError.unavailable }
  func fetchBearerFlags(festivalID: String?) async throws -> [BearerOwnedFlag] { throw BearerError.unavailable }
  func fetchPinnedFlag() async throws -> BearerPinnedFlag? { throw BearerError.unavailable }
}
