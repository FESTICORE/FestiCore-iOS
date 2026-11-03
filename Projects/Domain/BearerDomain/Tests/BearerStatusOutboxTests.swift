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

  private func status(_ lifecycle: BearerFlagLifecycle) -> BearerFlagStatus {
    BearerFlagStatus(flagID: "flg_1", lifecycle: lifecycle, zoneID: "zone_a", activity: nil, updatedAt: now)
  }

  private func makeOutbox(
    _ repository: ScriptedRepository,
    auth: StubAuthService = StubAuthService(),
    clock: some Clock<Duration> = ImmediateClock(),
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

  @Test("쌓인 두 변경을 누른 순서대로 같은 멱등키로 보낸다")
  func sendsInOrder() async {
    let repository = ScriptedRepository([.success(status(.resting)), .success(status(.ended))])
    let outbox = makeOutbox(repository)

    await outbox.enqueue(flagID: "flg_1", request: request(.rest, "key-1"))
    await outbox.enqueue(flagID: "flg_1", request: request(.end, "key-2", offset: 1))
    await outbox.waitUntilIdle()

    #expect(await repository.sentKeys == ["key-1", "key-2"])
    #expect(await outbox.pending(flagID: "flg_1").isEmpty)
  }

  @Test("연결이 없으면 남겨 두고 같은 멱등키로 다시 보낸다")
  func retriesOffline() async {
    let repository = ScriptedRepository([.failure(.offline), .success(status(.resting))])
    let outbox = makeOutbox(repository)

    await outbox.enqueue(flagID: "flg_1", request: request(.rest, "key-1"))
    await outbox.waitUntilIdle()

    #expect(await repository.sentKeys == ["key-1", "key-1"])
    #expect(await outbox.pending(flagID: "flg_1").isEmpty)
  }

  @Test("429면 기다렸다가 다시 보낸다")
  func retriesRateLimited() async {
    let repository = ScriptedRepository([.failure(.rateLimited), .success(status(.resting))])
    let outbox = makeOutbox(repository)

    await outbox.enqueue(flagID: "flg_1", request: request(.rest, "key-1"))
    await outbox.waitUntilIdle()

    #expect(await repository.sentKeys == ["key-1", "key-1"])
  }

  @Test("401이면 대기열을 남기고 멈췄다가 다시 시작하면 이어서 보낸다")
  func keepsQueueOnUnauthorized() async {
    let repository = ScriptedRepository([.failure(.notAuthenticated), .success(status(.resting))])
    let outbox = makeOutbox(repository)
    let events = await outbox.events(flagID: "flg_1")

    await outbox.enqueue(flagID: "flg_1", request: request(.rest, "key-1"))
    await outbox.waitUntilIdle()
    #expect(await outbox.pending(flagID: "flg_1").count == 1)

    await outbox.resume()
    await outbox.waitUntilIdle()
    #expect(await repository.sentKeys == ["key-1", "key-1"])
    #expect(await outbox.pending(flagID: "flg_1").isEmpty)

    var received: [BearerOutboxEvent] = []
    for await event in events {
      received.append(event)
      if case .sent = event { break }
    }
    #expect(received.contains(.needsLogin))
  }

  @Test("서버 오류가 계속되면 정해진 횟수 뒤 멈추고 대기열은 남긴다")
  func givesUpAfterServerErrors() async {
    let failures = Array(repeating: Result<BearerFlagStatus, BearerError>.failure(.unavailable), count: 10)
    let repository = ScriptedRepository(failures)
    let outbox = makeOutbox(repository)

    await outbox.enqueue(flagID: "flg_1", request: request(.rest, "key-1"))
    await outbox.waitUntilIdle()

    #expect(await repository.sentKeys.count == BearerStatusOutboxImpl.maxServerRetries + 1)
    #expect(await outbox.pending(flagID: "flg_1").count == 1)
  }

  @Test("서버가 받지 않는 변경이면 그 깃발의 대기열을 비운다")
  func dropsRejected() async {
    let repository = ScriptedRepository([.failure(.stale)])
    let outbox = makeOutbox(repository)

    await outbox.enqueue(flagID: "flg_1", request: request(.rest, "key-1"))
    await outbox.enqueue(flagID: "flg_1", request: request(.end, "key-2", offset: 1))
    await outbox.waitUntilIdle()

    #expect(await repository.sentKeys == ["key-1"])
    #expect(await outbox.pending(flagID: "flg_1").isEmpty)
  }

  @Test("다른 계정으로 바뀌면 이전 계정의 대기열을 보내지 않고 버린다")
  func dropsOtherAccount() async {
    let auth = StubAuthService(userID: "usr_a")
    let repository = ScriptedRepository([.failure(.notAuthenticated)])
    let outbox = makeOutbox(repository, auth: auth)

    await outbox.enqueue(flagID: "flg_1", request: request(.rest, "key-1"))
    await outbox.waitUntilIdle()
    await auth.setUserID("usr_b")
    await outbox.resume()
    await outbox.waitUntilIdle()

    #expect(await repository.sentKeys == ["key-1"])
    #expect(await outbox.pending(flagID: "flg_1").isEmpty)
  }

  @Test("앱을 다시 켜도 파일에 남긴 대기열을 읽는다")
  func persists() async throws {
    let url = FileManager.default.temporaryDirectory.appendingPathComponent("outbox-\(UUID().uuidString).json")
    defer { try? FileManager.default.removeItem(at: url) }
    let first = makeOutbox(ScriptedRepository([.failure(.notAuthenticated)]), fileURL: url)
    let restart = request(.restart(zoneID: "zone_a", activity: .sing), "key-1")
    await first.enqueue(flagID: "flg_1", request: restart)
    await first.waitUntilIdle()

    let second = makeOutbox(ScriptedRepository([]), fileURL: url)
    #expect(await second.pending(flagID: "flg_1") == [restart])
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
