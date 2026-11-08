import Foundation
import Darwin
import Testing
import FestiCorePackInterface
import FestiCoreNetworkInterface
@testable import FestiCorePack

@Suite("오프라인 팩 복구")
struct PackSyncTests {
  private let id = "fst_example"

  @Test("앱 테스트 호스트의 기본 팩 캐시는 비어 있다")
  func defaultCachedPacksAreEmpty() async throws {
    #expect(try await PackSyncServiceDependency.testValue.cachedPacks().isEmpty)
  }

  @Test("기본 팩 동기화는 프로세스 종료 대신 오류를 반환한다")
  func unimplementedSyncFailsWithError() async {
    let failed: Bool
    do {
      _ = try await PackSyncServiceDependency.testValue.sync(for: id)
      failed = false
    } catch {
      failed = true
    }
    #expect(failed)
  }

  @Test("완성된 팩은 새 서비스 인스턴스에서 네트워크 없이 복원한다")
  func restoresAfterRestart() async throws {
    let directory = temporaryDirectory()
    let socket = ScriptSocket { request in [snapshot(request, version: 1, etag: "\"one\"")] }
    let online = service(directory: directory, sockets: [socket])
    let result = try await online.sync(for: id)
    guard case .updated(let saved) = result else { Issue.record("snapshot expected"); return }

    let offline = NetworkPackSyncService(
      cacheDirectory: directory,
      client: SocketFactory.unconfigured
    )
    #expect(try await offline.cachedPack(for: id) == saved)
    await #expect(throws: PackSyncError.unconfigured) { try await offline.sync(for: id) }
  }

  @Test("팩 WebSocket은 공개 팩 채널 요청으로 연다")
  func connectsWithPackSocketRequest() async throws {
    let factory = SocketFactory([
      ScriptSocket { request in
        return [snapshot(
          request,
          version: 1,
          etag: "\"one\""
        )]
      }
    ])
    let syncService = NetworkPackSyncService(
      cacheDirectory: temporaryDirectory(),
      client: factory
    )

    _ = try await syncService.sync(for: id)

    #expect(factory.paths == ["api/v1/festivals/updates"])
  }

  @Test("오프라인 목록은 검증된 팩만 정렬해 반환한다")
  func listsOnlyValidCachedPacks() async throws {
    let directory = temporaryDirectory()
    let cache = PackCache(directory: directory)
    for festivalID in ["fst_z", "fst_a"] {
      let pack = Data("{\"id\":\"\(festivalID)\",\"packVersion\":1}".utf8)
      try cache.save(CachedFestivalPack(
        festivalID: festivalID, packVersion: 1, etag: "\"one\"", pack: pack
      ))
    }
    try Data("invalid".utf8).write(to: directory.appendingPathComponent("fst_corrupt.json"))
    try Data("unrelated".utf8).write(to: directory.appendingPathComponent("readme.txt"))
    try FileManager.default.createSymbolicLink(
      at: directory.appendingPathComponent("fst_link.json"),
      withDestinationURL: directory.appendingPathComponent("fst_a.json")
    )

    let offline = NetworkPackSyncService(
      cacheDirectory: directory,
      client: SocketFactory.unconfigured
    )
    #expect(try await offline.cachedPacks().map(\.festivalID) == ["fst_a", "fst_z"])
  }

  @Test("캐시 디렉터리가 없으면 오프라인 목록은 비어 있다")
  func missingCacheDirectoryHasNoPacks() async throws {
    let offline = NetworkPackSyncService(
      cacheDirectory: temporaryDirectory(),
      client: SocketFactory.unconfigured
    )
    #expect(try await offline.cachedPacks().isEmpty)
  }

  @Test("끊긴 연결 뒤 이전 ETag로 재접속해 최신 팩을 저장한다")
  func reconnectsWithStoredETag() async throws {
    let directory = temporaryDirectory()
    let first = ScriptSocket { request in [snapshot(request, version: 1, etag: "\"one\"")] }
    let second = ScriptSocket { request in [snapshot(request, version: 2, etag: "\"two\"")] }
    let service = service(directory: directory, sockets: [first, second])
    var versions: [Int] = []
    var reconnectCount = 0
    for try await result in service.updates(for: id) {
      if case .updated(let pack) = result { versions.append(pack.packVersion) }
      if case .reconnecting = result { reconnectCount += 1 }
      if versions.count == 2 { break }
    }
    #expect(versions == [1, 2])
    #expect(reconnectCount == 1)
    #expect(second.requests.count == 1)
    #expect(second.requests[0]["ifNoneMatch"] as? String == "\"one\"")
    #expect(try await service.cachedPack(for: id)?.packVersion == 2)
  }

  @Test("소켓 종료와 핸드셰이크 전송 오류 뒤 저장된 ETag로 재접속한다")
  func reconnectsAfterSocketAndHandshakeErrors() async throws {
    try await assertReconnects(after: NSError(domain: NSPOSIXErrorDomain, code: Int(ENOTCONN)))
    try await assertReconnects(after: NSError(domain: NSPOSIXErrorDomain, code: Int(ECONNABORTED)))
    try await assertReconnects(after: URLError(.badServerResponse))
  }

  @Test("조용한 업데이트 소켓의 유휴 만료는 이미지 복구 이벤트 없이 갱신한다")
  func idleUpdateTimeoutDoesNotSignalOutage() async throws {
    let first = ScriptSocket(emptyError: PackSyncError.timeout) { request in
      [snapshot(request, version: 1, etag: "\"one\"")]
    }
    let second = ScriptSocket { request in
      [message("pack.not_modified", request["requestId"] as? String ?? "", [
        "festivalId": "fst_example", "packVersion": 1, "etag": "\"one\""
      ])]
    }
    let syncService = service(directory: temporaryDirectory(), sockets: [first, second])
    var packResults = 0
    var reconnectCount = 0
    for try await result in syncService.updates(for: id) {
      if case .updated = result { packResults += 1 }
      if case .notModified = result { packResults += 1 }
      if case .reconnecting = result { reconnectCount += 1 }
      if packResults == 2 { break }
    }
    #expect(packResults == 2)
    #expect(reconnectCount == 0)
    #expect(second.requests.first?["ifNoneMatch"] as? String == "\"one\"")
  }

  @Test("유휴 만료로 소켓이 취소되어도 원래 타임아웃을 전달한다")
  func receiveTimeoutWinsSocketCancelError() async throws {
    let cancellationErrors: [any Error] = [
      URLError(.cancelled),
      NSError(domain: NSPOSIXErrorDomain, code: Int(ENOTCONN))
    ]
    for error in cancellationErrors {
      let socket = ScriptSocket(waitUntilCancelled: true, emptyError: error) { _ in [] }
      await #expect(throws: PackSyncError.timeout) {
        try await PackWire.receiveText(on: socket, timeoutNanoseconds: 10_000_000)
      }
      #expect(socket.cancelCount > 0)
    }
  }

  @Test("첫 연결 실패는 기존 오프라인 상태를 바꾸지 않고 재시도한다")
  func firstConnectionFailureDoesNotSignalReconnect() async throws {
    let unavailable = ScriptSocket(emptyError: URLError(.notConnectedToInternet)) { _ in [] }
    let online = ScriptSocket { request in [snapshot(request, version: 1, etag: "\"one\"")] }
    let syncService = service(directory: temporaryDirectory(), sockets: [unavailable, online])
    var reconnectCount = 0
    var receivedPack = false
    for try await result in syncService.updates(for: id) {
      if case .reconnecting = result { reconnectCount += 1 }
      if case .updated = result { receivedPack = true; break }
    }
    #expect(receivedPack)
    #expect(reconnectCount == 0)
  }

  @Test("반복해서 거부된 웹소켓 연결도 느린 재시도 후 자동 복구한다")
  func repeatedRejectedHandshakesRecover() async throws {
    let rejected = (0..<3).map { _ in
      ScriptSocket(emptyError: URLError(.badServerResponse)) { _ in [] }
    }
    let recovered = ScriptSocket { request in [snapshot(request, version: 1, etag: "\"one\"")] }
    let syncService = service(
      directory: temporaryDirectory(), sockets: rejected + [recovered],
      rejectedRetryNanoseconds: 1_000_000
    )
    var reconnectCount = 0
    var receivedPack = false
    for try await result in syncService.updates(for: id) {
      if case .reconnecting = result { reconnectCount += 1 }
      if case .updated = result { receivedPack = true; break }
    }
    #expect(receivedPack)
    #expect(reconnectCount == 0)
    #expect(rejected.allSatisfy { $0.requests.count == 1 })
    #expect(recovered.requests.count == 1)
  }

  private func assertReconnects(after error: Error) async throws {
    let first = ScriptSocket(emptyError: error) { request in
      [snapshot(request, version: 1, etag: "\"one\"")]
    }
    let second = ScriptSocket { request in
      [snapshot(request, version: 2, etag: "\"two\"")]
    }
    let syncService = service(directory: temporaryDirectory(), sockets: [first, second])
    var versions: [Int] = []
    var reconnectCount = 0
    for try await result in syncService.updates(for: id) {
      if case .updated(let pack) = result { versions.append(pack.packVersion) }
      if case .reconnecting = result { reconnectCount += 1 }
      if versions.count == 2 { break }
    }
    #expect(versions == [1, 2])
    #expect(reconnectCount == 1)
    #expect(second.requests.count == 1)
    #expect(second.requests.first?["ifNoneMatch"] as? String == "\"one\"")
    #expect(try await syncService.cachedPack(for: id)?.packVersion == 2)
  }

  @Test("청크 일부 또는 잘못된 SHA-256은 기존 팩을 교체하지 않는다")
  func invalidChunksKeepOldPack() async throws {
    let directory = temporaryDirectory()
    let initial = ScriptSocket { request in [snapshot(request, version: 1, etag: "\"one\"")] }
    let saved = service(directory: directory, sockets: [initial])
    _ = try await saved.sync(for: id)

    for isPartial in [true, false] {
      let failing = ScriptSocket { request in
        let requestID = request["requestId"] as? String ?? ""
        let newPack = Data("{\"id\":\"fst_example\",\"packVersion\":2}".utf8)
        let start = message("pack.start", requestID, [
          "festivalId": "fst_example", "packVersion": 2, "etag": "\"two\"",
          "totalBytes": newPack.count, "chunkCount": 1,
          "sha256": isPartial ? PackCache.digest(newPack) : String(repeating: "0", count: 64)
        ])
        if isPartial { return [start] }
        return [start,
                message("pack.chunk", requestID, ["index": 0, "base64": newPack.base64EncodedString()]),
                message("pack.complete", requestID, nil)]
      }
      let retry = service(directory: directory, sockets: [failing])
      await #expect(throws: Error.self) { try await retry.sync(for: id) }
      #expect(try await retry.cachedPack(for: id)?.packVersion == 1)
      #expect(failing.requests.first?["ifNoneMatch"] as? String == "\"one\"")
    }
  }

  @Test("완성된 청크는 해시와 순서 검증 후 저장한다")
  func completeChunksSave() async throws {
    let directory = temporaryDirectory()
    let socket = ScriptSocket { request in
      let requestID = request["requestId"] as? String ?? ""
      if (request["data"] as? [String: Any])?["ifNoneMatch"] as? String == "\"three\"" {
        return [message("pack.not_modified", requestID, [
          "festivalId": "fst_example", "packVersion": 3, "etag": "\"three\""
        ])]
      }
      let pack = Data("{\"id\":\"fst_example\",\"packVersion\":3}".utf8)
      return [
        message("pack.start", requestID, ["festivalId": "fst_example", "packVersion": 3,
                                          "etag": "\"three\"", "totalBytes": pack.count, "chunkCount": 1,
                                          "sha256": PackCache.digest(pack)]),
        message("pack.updated", "", ["festivalId": "fst_example", "packVersion": 3]),
        message("pack.chunk", requestID, ["index": 0, "base64": pack.base64EncodedString()]),
        message("pack.updated", "", ["festivalId": "fst_example", "packVersion": 3]),
        message("pack.complete", requestID, nil)
      ]
    }
    let result = try await service(directory: directory, sockets: [socket]).sync(for: id)
    let pack: CachedFestivalPack
    switch result {
    case .updated(let value), .notModified(let value): pack = value
    case .retryAfter, .reconnecting: Issue.record("chunked pack expected"); return
    }
    #expect(pack.packVersion == 3)
    #expect(socket.requests.count == 2)
  }

  @Test("단발 다운로드는 검증된 청크의 실제 누적 바이트와 캐시 저장 완료를 순서대로 보낸다")
  func downloadReportsReceivedBytesThenSavedPack() async throws {
    let directory = temporaryDirectory()
    let pack = Data("{\"id\":\"fst_example\",\"packVersion\":4,\"padding\":\"\(String(repeating: "x", count: 50_000))\"}".utf8)
    let socket = ScriptSocket { request in
      let requestID = request["requestId"] as? String ?? ""
      let chunks = stride(from: 0, to: pack.count, by: 48 * 1024).enumerated().map { index, offset in
        message("pack.chunk", requestID, [
          "index": index,
          "base64": pack.subdata(in: offset..<min(offset + 48 * 1024, pack.count)).base64EncodedString()
        ])
      }
      return [message("pack.start", requestID, [
        "festivalId": "fst_example", "packVersion": 4, "etag": "\"four\"",
        "totalBytes": pack.count, "chunkCount": chunks.count, "sha256": PackCache.digest(pack)
      ])] + chunks + [message("pack.complete", requestID, nil)]
    }
    let syncService = service(directory: directory, sockets: [socket])
    var events: [PackDownloadEvent] = []
    for try await event in syncService.download(for: id) { events.append(event) }

    guard events.count == 3 else { Issue.record("progress twice and saved pack expected"); return }
    #expect(events[0] == .progress(.init(receivedBytes: 48 * 1024, totalBytes: pack.count)))
    #expect(events[1] == .progress(.init(receivedBytes: pack.count, totalBytes: pack.count)))
    guard case .finished(.updated(let saved)) = events[2] else {
      Issue.record("saved pack expected"); return
    }
    #expect(saved.pack == pack)
    #expect(try await syncService.cachedPack(for: id) == saved)
  }

  @Test("단일 스냅샷은 가짜 바이트 진행률 없이 저장 완료만 보낸다")
  func snapshotDownloadHasNoNumericProgress() async throws {
    let socket = ScriptSocket { request in [snapshot(request, version: 1, etag: "\"one\"")] }
    let syncService = service(directory: temporaryDirectory(), sockets: [socket])
    var events: [PackDownloadEvent] = []
    for try await event in syncService.download(for: id) { events.append(event) }
    #expect(events.count == 1)
    guard case .finished(.updated) = events[0] else { Issue.record("saved snapshot expected"); return }
  }

  @Test("4MiB가 넘는 팩도 작은 청크로 받아 저장한다")
  func largePackDownloadsBeyondSingleMessageLimit() async throws {
    let pack = Data("{\"id\":\"fst_example\",\"packVersion\":4,\"padding\":\"\(String(repeating: "x", count: 4 * 1024 * 1024))\"}".utf8)
    let socket = ScriptSocket { request in
      let requestID = request["requestId"] as? String ?? ""
      let chunks = stride(from: 0, to: pack.count, by: 48 * 1024).enumerated().map { index, offset in
        message("pack.chunk", requestID, [
          "index": index,
          "base64": pack.subdata(in: offset..<min(offset + 48 * 1024, pack.count)).base64EncodedString()
        ])
      }
      return [message("pack.start", requestID, [
        "festivalId": "fst_example", "packVersion": 4, "etag": "\"four\"",
        "totalBytes": pack.count, "chunkCount": chunks.count, "sha256": PackCache.digest(pack)
      ])] + chunks + [message("pack.complete", requestID, nil)]
    }
    let syncService = service(directory: temporaryDirectory(), sockets: [socket])
    var lastProgress: PackDownloadProgress?
    var savedPack: CachedFestivalPack?
    for try await event in syncService.download(for: id) {
      switch event {
      case let .progress(progress): lastProgress = progress
      case let .finished(.updated(pack)): savedPack = pack
      case .reset, .finished: break
      }
    }
    #expect(pack.count > 4 * 1024 * 1024)
    #expect(lastProgress == PackDownloadProgress(receivedBytes: pack.count, totalBytes: pack.count))
    #expect(savedPack?.pack == pack)
  }

  @Test("전송 중 서버 갱신 알림으로 재요청하면 이전 진행률을 지운다")
  func updateHintResetsDownloadProgress() async throws {
    let pack = Data("{\"id\":\"fst_example\",\"packVersion\":1}".utf8)
    let socket = ScriptSocket { request in
      let requestID = request["requestId"] as? String ?? ""
      if (request["data"] as? [String: Any])?["ifNoneMatch"] != nil {
        return [snapshot(request, version: 2, etag: "\"two\"")]
      }
      return [
        message("pack.start", requestID, [
          "festivalId": "fst_example", "packVersion": 1, "etag": "\"one\"",
          "totalBytes": pack.count, "chunkCount": 1, "sha256": PackCache.digest(pack)
        ]),
        message("pack.updated", "", ["festivalId": "fst_example", "packVersion": 2]),
        message("pack.chunk", requestID, ["index": 0, "base64": pack.base64EncodedString()]),
        message("pack.complete", requestID, nil)
      ]
    }
    let syncService = service(directory: temporaryDirectory(), sockets: [socket])
    var events: [PackDownloadEvent] = []
    for try await event in syncService.download(for: id) { events.append(event) }

    #expect(events.count == 3)
    #expect(events[0] == .progress(.init(receivedBytes: pack.count, totalBytes: pack.count)))
    #expect(events[1] == .reset)
    guard case .finished(.updated(let saved)) = events[2] else {
      Issue.record("new snapshot expected"); return
    }
    #expect(saved.packVersion == 2)
    #expect(socket.requests.count == 2)
  }

  @Test("활성 전송은 재시도 대기 예산보다 오래 걸려도 완료한다")
  func activeTransferDoesNotConsumeRetryBudget() async throws {
    let pack = Data("{\"id\":\"fst_example\",\"packVersion\":1}".utf8)
    let socket = ScriptSocket(delayNanoseconds: 20_000_000) { request in
      let requestID = request["requestId"] as? String ?? ""
      return [
        message("pack.start", requestID, [
          "festivalId": "fst_example", "packVersion": 1, "etag": "\"one\"",
          "totalBytes": pack.count, "chunkCount": 1, "sha256": PackCache.digest(pack)
        ]),
        message("pack.chunk", requestID, ["index": 0, "base64": pack.base64EncodedString()]),
        message("pack.complete", requestID, nil)
      ]
    }
    let syncService = NetworkPackSyncService(
      cacheDirectory: temporaryDirectory(), downloadRetryBudgetNanoseconds: 10_000_000,
      client: SocketFactory([socket])
    )
    var finished = false
    for try await event in syncService.download(for: id) {
      if case .finished(.updated) = event { finished = true }
    }
    #expect(finished)
    #expect(socket.requests.count == 1)
  }

  @Test("단발 다운로드의 PACK_BUSY는 최초 요청 포함 세 번만 시도한다")
  func busyDownloadIsBounded() async throws {
    let socket = ScriptSocket { request in
      [message("pack.retry", request["requestId"] as? String ?? "", [
        "festivalId": "fst_example", "retryAfterMs": 1
      ])]
    }
    let syncService = service(directory: temporaryDirectory(), sockets: [socket])
    var events: [PackDownloadEvent] = []
    do {
      for try await event in syncService.download(for: id) { events.append(event) }
      Issue.record("PACK_BUSY expected")
    } catch PackSyncError.server(let code) {
      #expect(code == "PACK_BUSY")
    }
    #expect(events == [.reset, .reset])
    #expect(socket.requests.count == 3)
  }

  @Test("서버 재시도 간격이 남은 예산보다 길면 조기 재요청하지 않는다")
  func busyDownloadHonorsServerRetryDelay() async throws {
    let socket = ScriptSocket { request in
      [message("pack.retry", request["requestId"] as? String ?? "", [
        "festivalId": "fst_example", "retryAfterMs": 50
      ])]
    }
    let syncService = NetworkPackSyncService(
      cacheDirectory: temporaryDirectory(), downloadRetryBudgetNanoseconds: 10_000_000,
      client: SocketFactory([socket])
    )
    await #expect(throws: PackSyncError.timeout) {
      for try await _ in syncService.download(for: id) {}
    }
    #expect(socket.requests.count == 1)
  }

  @Test("단발 다운로드 취소는 대기 중인 웹소켓을 닫는다")
  func cancelledDownloadClosesSocket() async throws {
    let socket = ScriptSocket(waitUntilCancelled: true) { _ in [] }
    let syncService = service(directory: temporaryDirectory(), sockets: [socket])
    let task = Task {
      for try await _ in syncService.download(for: id) {}
    }
    for _ in 0..<50 {
      if !socket.requests.isEmpty { break }
      try await Task.sleep(nanoseconds: 10_000_000)
    }
    #expect(socket.requests.count == 1)
    task.cancel()
    _ = try? await task.value
    #expect(socket.cancelCount > 0)
  }

  @Test("변경 없음·재시도·서버 오류는 저장된 팩을 보존한다")
  func nonSnapshotResponsesKeepCache() async throws {
    let directory = temporaryDirectory()
    let initial = service(directory: directory, sockets: [
      ScriptSocket { request in [snapshot(request, version: 1, etag: "\"one\"")] }
    ])
    _ = try await initial.sync(for: id)

    let unchanged = service(directory: directory, sockets: [ScriptSocket { request in
      [message("pack.not_modified", request["requestId"] as? String ?? "", [
        "festivalId": "fst_example", "packVersion": 1, "etag": "\"one\""
      ])]
    }])
    guard case .notModified(let cached) = try await unchanged.sync(for: id) else {
      Issue.record("not_modified expected"); return
    }
    #expect(cached.packVersion == 1)

    let retry = service(directory: directory, sockets: [ScriptSocket { request in
      [message("pack.retry", request["requestId"] as? String ?? "", [
        "festivalId": "fst_example", "packVersion": 2, "retryAfterMs": 1000
      ])]
    }])
    #expect(try await retry.sync(for: id) == .retryAfter(1))

    let unavailable = service(directory: directory, sockets: [ScriptSocket { request in
      [message("pack.error", request["requestId"] as? String ?? "", ["code": "PACK_UNAVAILABLE"])]
    }])
    await #expect(throws: PackSyncError.server("PACK_UNAVAILABLE")) {
      try await unavailable.sync(for: id)
    }
    #expect(try await unavailable.cachedPack(for: id)?.packVersion == 1)

    let busy = service(directory: directory, sockets: [ScriptSocket { request in
      [message("pack.error", request["requestId"] as? String ?? "", [
        "code": "PACK_BUSY", "retryAfterMs": 1500
      ])]
    }])
    #expect(try await busy.sync(for: id) == .retryAfter(1.5))
    #expect(try await busy.cachedPack(for: id)?.packVersion == 1)
  }

  @Test("변경 없음 응답을 받으면 저장된 팩의 확인 시각을 새로 남긴다")
  func notModifiedMarksCheckedAt() async throws {
    let directory = temporaryDirectory()
    let initial = service(directory: directory, sockets: [
      ScriptSocket { request in [snapshot(request, version: 1, etag: "\"one\"")] }
    ])
    _ = try await initial.sync(for: id)
    let file = directory.appendingPathComponent("\(id).json")
    let old = Date(timeIntervalSince1970: 1_000_000)
    try FileManager.default.setAttributes([.modificationDate: old], ofItemAtPath: file.path)
    #expect(try await initial.cachedPack(for: id)?.checkedAt == old)

    let unchanged = service(directory: directory, sockets: [ScriptSocket { request in
      [message("pack.not_modified", request["requestId"] as? String ?? "", [
        "festivalId": "fst_example", "packVersion": 1, "etag": "\"one\""
      ])]
    }])
    guard case .notModified(let cached) = try await unchanged.sync(for: id) else {
      Issue.record("not_modified expected"); return
    }
    #expect((cached.checkedAt ?? old) > old)
  }

  @Test("팩을 지우면 디스크 파일과 오프라인 목록에서 사라진다")
  func deletePackRemovesFile() async throws {
    let directory = temporaryDirectory()
    let syncService = service(directory: directory, sockets: [
      ScriptSocket { request in [snapshot(request, version: 1, etag: "\"one\"")] }
    ])
    _ = try await syncService.sync(for: id)
    let file = directory.appendingPathComponent("\(id).json")
    #expect(FileManager.default.fileExists(atPath: file.path))

    try await syncService.deletePack(for: id)

    #expect(!FileManager.default.fileExists(atPath: file.path))
    #expect(try await syncService.cachedPack(for: id) == nil)
    #expect(try await syncService.cachedPacks().isEmpty)
    // 이미 지운 팩을 다시 지워도 오류가 아니다.
    try await syncService.deletePack(for: id)
  }

  @Test("응답을 기다리는 동안 팩을 지우면 늦은 응답이 팩을 되살리지 않는다", arguments: [false, true])
  func lateResponseAfterDeleteDoesNotRestorePack(notModified: Bool) async throws {
    let directory = temporaryDirectory()
    let slow = ScriptSocket(delayNanoseconds: 200_000_000) { request in
      if notModified {
        return [message("pack.not_modified", request["requestId"] as? String ?? "", [
          "festivalId": "fst_example", "packVersion": 1, "etag": "\"one\""
        ])]
      }
      return [snapshot(request, version: 2, etag: "\"two\"")]
    }
    let syncService = service(directory: directory, sockets: [
      ScriptSocket { request in [snapshot(request, version: 1, etag: "\"one\"")] },
      slow,
      ScriptSocket { request in [snapshot(request, version: 3, etag: "\"three\"")] }
    ])
    _ = try await syncService.sync(for: id)
    let late = Task { try await syncService.sync(for: id) }
    for _ in 0..<50 {
      if !slow.requests.isEmpty { break }
      try await Task.sleep(nanoseconds: 10_000_000)
    }

    try await syncService.deletePack(for: id)

    await #expect(throws: PackSyncError.packDeleted) { try await late.value }
    #expect(try await syncService.cachedPack(for: id) == nil)
    // 세대가 내려가지 않아 다음 요청은 정상으로 저장한다.
    guard case .updated(let pack) = try await syncService.sync(for: id) else {
      Issue.record("updated pack expected"); return
    }
    #expect(pack.packVersion == 3)
  }

  @Test("감시 중 팩을 지우면 업데이트 알림을 받아도 다시 내려받지 않고 감시를 멈춘다")
  func updateHintAfterDeleteDoesNotDownloadAgain() async throws {
    let directory = temporaryDirectory()
    let socket = ScriptSocket(waitUntilCancelled: true) { request in
      [snapshot(request, version: 1, etag: "\"one\"")]
    }
    let syncService = service(directory: directory, sockets: [socket])
    var updates = 0
    for try await result in syncService.updates(for: id) {
      guard case .updated = result else { continue }
      updates += 1
      if updates > 1 { break }
      try await syncService.deletePack(for: id)
      socket.push(message("pack.updated", "", ["festivalId": "fst_example", "packVersion": 2]))
    }
    #expect(updates == 1)
    #expect(socket.requests.count == 1)
    #expect(try await syncService.cachedPack(for: id) == nil)
  }

  @Test("재접속 지연은 지수 증가하고 성공 후 초기화된다")
  func reconnectBackoff() {
    var backoff = ReconnectBackoff()
    #expect((0..<7).map { _ in backoff.nextDelayNanoseconds() } ==
            [1, 2, 4, 8, 16, 30, 30].map { UInt64($0) * 1_000_000_000 })
    backoff.reset()
    #expect(backoff.nextDelayNanoseconds() == 1_000_000_000)
  }

  @Test("구버전 응답과 느린 동일 버전 응답은 최신 캐시를 덮지 않는다")
  func staleResponsesCannotReplaceCache() async throws {
    let directory = temporaryDirectory()
    let older = ScriptSocket(delayNanoseconds: 200_000_000) { request in
      [snapshot(request, version: 1, etag: "\"old\"")]
    }
    let newer = ScriptSocket { request in [snapshot(request, version: 1, etag: "\"new\"")] }
    let syncService = service(directory: directory, sockets: [older, newer])
    let first = Task { try await syncService.sync(for: id) }
    for _ in 0..<50 {
      if !older.requests.isEmpty { break }
      try await Task.sleep(nanoseconds: 10_000_000)
    }
    _ = try await syncService.sync(for: id)
    _ = try await first.value
    #expect(try await syncService.cachedPack(for: id)?.etag == "\"new\"")

    let promoted = service(directory: directory, sockets: [ScriptSocket { request in
      [snapshot(request, version: 2, etag: "\"two\"")]
    }])
    _ = try await promoted.sync(for: id)
    let obsolete = service(directory: directory, sockets: [ScriptSocket { request in
      [snapshot(request, version: 1, etag: "\"obsolete\"")]
    }])
    guard case .notModified(let current) = try await obsolete.sync(for: id) else {
      Issue.record("older version must be discarded"); return
    }
    #expect(current.etag == "\"two\"")
    #expect(try await obsolete.cachedPack(for: id)?.etag == "\"two\"")
  }

  @Test("응답 전 업데이트 알림을 받으면 저장된 ETag로 즉시 다시 요청한다")
  func updateHintBeforeSnapshotForcesRecheck() async throws {
    let socket = ScriptSocket { request in
      let id = request["requestId"] as? String ?? ""
      let data = request["data"] as? [String: Any] ?? [:]
      if data["ifNoneMatch"] == nil {
        return [message("pack.updated", "", ["festivalId": "fst_example", "packVersion": 2]),
                snapshot(request, version: 1, etag: "\"one\"")]
      }
      return [message("pack.snapshot", id, ["festivalId": "fst_example", "packVersion": 2,
                                            "etag": "\"two\"",
                                            "pack": ["id": "fst_example", "packVersion": 2]])]
    }
    let syncService = service(directory: temporaryDirectory(), sockets: [socket])
    guard case .updated(let pack) = try await syncService.sync(for: id) else {
      Issue.record("updated pack expected"); return
    }
    #expect(pack.packVersion == 2)
    #expect(socket.requests.count == 2)
    #expect(socket.requests[1]["ifNoneMatch"] as? String == "\"one\"")
  }

  @Test("응답 시간 초과 후 기존 팩이 유지된다")
  func timeoutKeepsOldPack() async throws {
    let directory = temporaryDirectory()
    let initial = service(directory: directory, sockets: [
      ScriptSocket { request in [snapshot(request, version: 1, etag: "\"one\"")] }
    ])
    _ = try await initial.sync(for: id)
    let slow = ScriptSocket(delayNanoseconds: 200_000_000) { request in
      [snapshot(request, version: 2, etag: "\"two\"")]
    }
    let retry = NetworkPackSyncService(
      cacheDirectory: directory,
      responseTimeoutNanoseconds: 20_000_000,
      client: SocketFactory([slow])
    )
    await #expect(throws: PackSyncError.timeout) { try await retry.sync(for: id) }
    #expect(try await retry.cachedPack(for: id)?.packVersion == 1)
  }

  @Test("텍스트가 아닌 웹소켓 메시지는 잘못된 팩 메시지로 처리하고 연결을 닫는다")
  func nonTextMessageClosesSocket() async throws {
    let socket = ScriptSocket(emptyError: FestiCoreWebSocketError.nonTextMessage) { _ in [] }
    let syncService = service(directory: temporaryDirectory(), sockets: [socket])

    await #expect(throws: PackSyncError.invalidMessage) { try await syncService.sync(for: id) }
    #expect(socket.cancelCount == 1)
  }

  @Test("단발 동기화가 끝나면 웹소켓 연결을 닫는다")
  func completedSyncClosesSocket() async throws {
    let socket = ScriptSocket { request in [snapshot(request, version: 1, etag: "\"one\"")] }
    let syncService = service(directory: temporaryDirectory(), sockets: [socket])

    _ = try await syncService.sync(for: id)
    #expect(socket.cancelCount == 1)
  }

  @Test("서버 오류는 무한 재접속하지 않고 스트림에 전달한다")
  func serverErrorFinishesStream() async throws {
    let socket = ScriptSocket { request in
      [message("pack.error", request["requestId"] as? String ?? "", ["code": "PACK_UNAVAILABLE"])]
    }
    let service = service(directory: temporaryDirectory(), sockets: [socket])
    do {
      for try await _ in service.updates(for: id) {}
      Issue.record("server error expected")
    } catch PackSyncError.server(let code) {
      #expect(code == "PACK_UNAVAILABLE")
    }
    #expect(socket.requests.count == 1)
  }

  @Test("나중에 시작한 요청이 실패하면 먼저 시작한 정상 응답을 저장한다")
  func failedNewerRequestDoesNotDiscardValidSnapshot() async throws {
    let directory = temporaryDirectory()
    let slow = ScriptSocket(delayNanoseconds: 150_000_000) { request in
      [snapshot(request, version: 1, etag: "\"valid\"")]
    }
    let failed = ScriptSocket { _ in [] }
    let syncService = service(directory: directory, sockets: [slow, failed])
    let first = Task { try await syncService.sync(for: id) }
    for _ in 0..<50 {
      if !slow.requests.isEmpty { break }
      try await Task.sleep(nanoseconds: 10_000_000)
    }
    await #expect(throws: URLError.self) { try await syncService.sync(for: id) }
    guard case .updated(let pack) = try await first.value else {
      Issue.record("earlier valid snapshot expected"); return
    }
    #expect(pack.etag == "\"valid\"")
    #expect(try await syncService.cachedPack(for: id)?.etag == "\"valid\"")
  }

  @Test("인증서 신뢰 실패는 무한 재연결하지 않고 스트림 오류로 전달한다")
  func certificateErrorFinishesStream() async throws {
    let socket = ScriptSocket(emptyError: URLError(.serverCertificateUntrusted)) { _ in [] }
    let syncService = service(directory: temporaryDirectory(), sockets: [socket])
    do {
      for try await _ in syncService.updates(for: id) {}
      Issue.record("certificate error expected")
    } catch let error as URLError {
      #expect(error.code == .serverCertificateUntrusted)
    }
    #expect(socket.requests.count == 1)
  }

  @Test("연속된 업데이트 힌트 5회는 완료가 아니라 재시도로 표시한다")
  func repeatedHintsRequireRetry() async throws {
    let socket = ScriptSocket { request in
      [message("pack.updated", "", ["festivalId": "fst_example", "packVersion": 2]),
       snapshot(request, version: 1, etag: "\"one\"")]
    }
    let syncService = service(directory: temporaryDirectory(), sockets: [socket])
    #expect(try await syncService.sync(for: id) == .retryAfter(1))
    #expect(socket.requests.count == 5)
    #expect(try await syncService.cachedPack(for: id)?.packVersion == 1)
  }

  private func service(
    directory: URL, sockets: [ScriptSocket],
    rejectedRetryNanoseconds: UInt64 = 300_000_000_000
  ) -> NetworkPackSyncService {
    let factory = SocketFactory(sockets)
    return NetworkPackSyncService(
      cacheDirectory: directory,
      rejectedHandshakeRetryNanoseconds: rejectedRetryNanoseconds,
      client: factory
    )
  }

  private func temporaryDirectory() -> URL {
    FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
  }

  private func snapshot(_ request: [String: Any], version: Int, etag: String) -> String {
    message("pack.snapshot", request["requestId"] as? String ?? "", [
      "festivalId": "fst_example", "packVersion": version, "etag": etag,
      "pack": ["id": "fst_example", "packVersion": version]
    ])
  }
}

private func message(_ event: String, _ requestID: String, _ data: [String: Any]?) -> String {
  var object: [String: Any] = ["event": event, "requestId": requestID]
  if let data { object["data"] = data }
  let bytes = try! JSONSerialization.data(withJSONObject: object)
  return String(decoding: bytes, as: UTF8.self)
}

private final class SocketFactory: FestiCoreWebSocketClient, @unchecked Sendable {
  /// 앱 서버 주소가 없는 클라이언트처럼 연결 전에 실패한다.
  static var unconfigured: SocketFactory {
    return SocketFactory(
      [],
      configured: false
    )
  }

  private let lock = NSLock()
  private let configured: Bool
  private var sockets: [ScriptSocket]
  private var requestedPaths: [String] = []

  init(
    _ sockets: [ScriptSocket],
    configured: Bool = true
  ) {
    self.sockets = sockets
    self.configured = configured
  }

  var paths: [String] {
    return lock.withLock { requestedPaths }
  }

  func connect<R: FestiCoreWebSocketRequest>(_ request: R) throws(FestiCoreNetworkError) -> any FestiCoreWebSocketConnection {
    guard configured else { throw .request(.invalidURL) }
    return lock.withLock {
      requestedPaths.append(request.path)
      return sockets.isEmpty ? ScriptSocket { _ in [] } : sockets.removeFirst()
    }
  }
}

private final class ScriptSocket: PackSocket, @unchecked Sendable {
  private let lock = NSLock()
  private let response: ([String: Any]) -> [String]
  private let delayNanoseconds: UInt64
  private let waitUntilCancelled: Bool
  private let emptyError: Error
  private var messages: [String] = []
  private var sent: [[String: Any]] = []
  private var cancellations = 0

  init(
    delayNanoseconds: UInt64 = 0,
    waitUntilCancelled: Bool = false,
    emptyError: Error = URLError(.networkConnectionLost),
    response: @escaping ([String: Any]) -> [String]
  ) {
    self.delayNanoseconds = delayNanoseconds
    self.waitUntilCancelled = waitUntilCancelled
    self.emptyError = emptyError
    self.response = response
  }

  var requests: [[String: Any]] { lock.withLock { sent } }
  var cancelCount: Int { lock.withLock { cancellations } }

  func send(_ text: String) async throws {
    let request = try JSONSerialization.jsonObject(with: Data(text.utf8)) as? [String: Any] ?? [:]
    lock.withLock {
      sent.append(request["data"] as? [String: Any] ?? [:])
      // Preserve requestId for response generation.
      messages.append(contentsOf: response(request))
    }
  }

  func receive() async throws -> String {
    if delayNanoseconds > 0 { try await Task.sleep(nanoseconds: delayNanoseconds) }
    if waitUntilCancelled {
      while lock.withLock({ messages.isEmpty && cancellations == 0 }) {
        try await Task.sleep(nanoseconds: 1_000_000)
      }
    }
    return try lock.withLock {
      guard !messages.isEmpty else { throw emptyError }
      return messages.removeFirst()
    }
  }

  func cancel() { lock.withLock { cancellations += 1 } }

  /// 서버가 요청 없이 보내는 메시지를 흉내 낸다.
  func push(_ text: String) { lock.withLock { messages.append(text) } }
}
