import Foundation
import Darwin
import FestiCorePackInterface
import FestiCoreNetworkInterface
import SQLiteData

private enum PackUpdateWaitError: Error { case idleTimeout, packDeleted }

public actor NetworkPackSyncService: PackSyncService {
  private let baseURL: URL?
  private let cache: PackCache
  private let client: any FestiCoreWebSocketClient
  private let responseTimeoutNanoseconds: UInt64
  private let rejectedHandshakeRetryNanoseconds: UInt64
  private let downloadRetryBudgetNanoseconds: UInt64
  private var requestGeneration: [String: Int] = [:]
  private var committedGeneration: [String: Int] = [:]
  /// 팩을 지운 횟수. 지우기 전에 시작한 업데이트 감시가 팩을 다시 받지 않게 한다.
  private var deletionCount: [String: Int] = [:]

  public init(
    baseURL: URL?,
    cacheDirectory: URL,
    database: (any DatabaseWriter)? = nil,
    client: any FestiCoreWebSocketClient
  ) {
    self.baseURL = baseURL
    cache = PackCache(directory: cacheDirectory, database: database)
    self.client = client
    responseTimeoutNanoseconds = 15_000_000_000
    rejectedHandshakeRetryNanoseconds = 300_000_000_000
    downloadRetryBudgetNanoseconds = 30_000_000_000
  }

  init(
    baseURL: URL?,
    cacheDirectory: URL,
    responseTimeoutNanoseconds: UInt64 = 15_000_000_000,
    rejectedHandshakeRetryNanoseconds: UInt64 = 300_000_000_000,
    downloadRetryBudgetNanoseconds: UInt64 = 30_000_000_000,
    database: (any DatabaseWriter)? = nil,
    client: any FestiCoreWebSocketClient
  ) {
    self.baseURL = baseURL
    cache = PackCache(directory: cacheDirectory, database: database)
    self.client = client
    self.responseTimeoutNanoseconds = responseTimeoutNanoseconds
    self.rejectedHandshakeRetryNanoseconds = rejectedHandshakeRetryNanoseconds
    self.downloadRetryBudgetNanoseconds = downloadRetryBudgetNanoseconds
  }

  public func cachedPack(for festivalID: String) async throws -> CachedFestivalPack? {
    try cache.load(festivalID)
  }

  public func cachedPacks() async throws -> [CachedFestivalPack] {
    try cache.loadAll()
  }

  public func sync(for festivalID: String) async throws -> PackSyncResult {
    let socket = client.connect(to: try endpoint())
    return try await withTaskCancellationHandler {
      defer { socket.cancel() }
      return try await synchronize(for: festivalID, on: socket)
    } onCancel: {
      socket.cancel()
    }
  }

  public nonisolated func download(for festivalID: String) -> AsyncThrowingStream<PackDownloadEvent, Error> {
    AsyncThrowingStream { continuation in
      let task = Task { await self.runDownload(for: festivalID, continuation: continuation) }
      continuation.onTermination = { @Sendable _ in task.cancel() }
    }
  }

  private func runDownload(
    for festivalID: String,
    continuation: AsyncThrowingStream<PackDownloadEvent, Error>.Continuation
  ) async {
    do {
      guard isValidFestivalID(festivalID) else { throw PackSyncError.invalidFestivalID }
      let socket = client.connect(to: try endpoint())
      defer { socket.cancel() }
      let progress: @Sendable (PackDownloadProgress) -> Void = { value in
        continuation.yield(.progress(value))
      }
      let reset: @Sendable () -> Void = { continuation.yield(.reset) }
      let result = try await withTaskCancellationHandler {
        var attempts = 0
        var remainingRetryBudget = downloadRetryBudgetNanoseconds
        while true {
          try Task.checkCancellation()
          if attempts > 0 { reset() }
          attempts += 1
          let result: PackSyncResult
          result = try await synchronize(for: festivalID, on: socket, onProgress: progress, onReset: reset)
          switch result {
          case .updated, .notModified:
            return result
          case let .retryAfter(seconds):
            guard attempts < 3 else { throw PackSyncError.server("PACK_BUSY") }
            // 서버가 지정한 간격을 줄이면 같은 바쁜 팩에 너무 빨리 재요청한다.
            guard seconds.isFinite, seconds > 0,
                  seconds <= Double(remainingRetryBudget) / 1_000_000_000 else {
              throw PackSyncError.timeout
            }
            let wait = UInt64(seconds * 1_000_000_000)
            try await Task.sleep(nanoseconds: wait)
            remainingRetryBudget -= wait
          case .reconnecting:
            throw PackSyncError.invalidMessage
          }
        }
      } onCancel: {
        socket.cancel()
      }
      continuation.yield(.finished(result))
      continuation.finish()
    } catch {
      continuation.finish(throwing: error)
    }
  }

  public func deletePack(for festivalID: String) async throws {
    try cache.delete(festivalID)
    // 진행 중이던 응답이 지운 팩을 다시 저장하지 않게 세대를 올린다.
    let generation = (requestGeneration[festivalID] ?? 0) + 1
    requestGeneration[festivalID] = generation
    committedGeneration[festivalID] = generation
    deletionCount[festivalID, default: 0] += 1
  }

  public nonisolated func updates(for festivalID: String) -> AsyncThrowingStream<PackSyncResult, Error> {
    AsyncThrowingStream { continuation in
      let task = Task { await self.runUpdates(for: festivalID, continuation: continuation) }
      continuation.onTermination = { @Sendable _ in task.cancel() }
    }
  }

  private func runUpdates(
    for festivalID: String,
    continuation: AsyncThrowingStream<PackSyncResult, Error>.Continuation
  ) async {
    guard isValidFestivalID(festivalID) else {
      continuation.finish(throwing: PackSyncError.invalidFestivalID)
      return
    }
    var backoff = ReconnectBackoff()
    var rejectedHandshakesSinceSuccess = 0
    var hasReceivedPack = false
    let deletionsAtStart = deletionCount[festivalID] ?? 0
    while !Task.isCancelled {
      do {
        try stopIfDeleted(festivalID, since: deletionsAtStart)
        let socket = client.connect(to: try endpoint())
        try await withTaskCancellationHandler {
          defer { socket.cancel() }
          while !Task.isCancelled {
            try stopIfDeleted(festivalID, since: deletionsAtStart)
            let result = try await synchronize(for: festivalID, on: socket)
            backoff.reset()
            rejectedHandshakesSinceSuccess = 0
            if case .updated = result { hasReceivedPack = true }
            if case .notModified = result { hasReceivedPack = true }
            continuation.yield(result)
            if case .retryAfter(let seconds) = result {
              try await Task.sleep(nanoseconds: UInt64(max(0.1, min(seconds, 30)) * 1_000_000_000))
              continue
            }
            while !Task.isCancelled {
              let text: String
              do {
                text = try await PackWire.receiveText(on: socket, timeoutNanoseconds: 60_000_000_000)
              } catch PackSyncError.timeout {
                throw PackUpdateWaitError.idleTimeout
              }
              let message = try PackWire.decode(text)
              if message.event == "pack.updated", message.data?["festivalId"] as? String == festivalID {
                break
              }
            }
          }
        } onCancel: {
          socket.cancel()
        }
      } catch {
        if Task.isCancelled { break }
        if case PackUpdateWaitError.packDeleted = error { break }
        if case PackSyncError.packDeleted = error { break }
        if error is PackUpdateWaitError {
          // A quiet stream is refreshed without showing an outage or retrying images.
          try? await Task.sleep(nanoseconds: backoff.nextDelayNanoseconds())
          continue
        }
        guard PackSyncError.isTransportFailure(error) else {
          continuation.finish(throwing: error)
          return
        }
        if let urlError = error as? URLError, urlError.code == .badServerResponse {
          rejectedHandshakesSinceSuccess += 1
          if rejectedHandshakesSinceSuccess >= 3 {
            // A short server deploy must not leave a foreground watch stopped indefinitely.
            try? await Task.sleep(nanoseconds: rejectedHandshakeRetryNanoseconds)
            continue
          }
        }
        // Socket loss does not discard a complete cache; reconnect with its ETag.
        if hasReceivedPack { continuation.yield(.reconnecting) }
        try? await Task.sleep(nanoseconds: backoff.nextDelayNanoseconds())
      }
    }
    continuation.finish()
  }

  /// 감시를 시작한 뒤 팩이 지워졌으면 다시 받지 않고 멈춘다.
  private func stopIfDeleted(_ festivalID: String, since count: Int) throws {
    if (deletionCount[festivalID] ?? 0) != count { throw PackUpdateWaitError.packDeleted }
  }

  private func synchronize(
    for festivalID: String, on socket: any PackSocket,
    onProgress: (@Sendable (PackDownloadProgress) -> Void)? = nil,
    onReset: (@Sendable () -> Void)? = nil
  ) async throws -> PackSyncResult {
    var receivedSnapshot = false
    for requestIndex in 0..<5 {
      if requestIndex > 0 { onReset?() }
      let reply = try await requestPack(for: festivalID, on: socket, onProgress: onProgress)
      if case .updated = reply.result { receivedSnapshot = true }
      if !reply.hadUpdateHint {
        if receivedSnapshot, case .notModified(let cached) = reply.result { return .updated(cached) }
        return reply.result
      }
    }
    // The server is publishing faster than this connection can catch up.
    return .retryAfter(1)
  }

  private struct Reply {
    let result: PackSyncResult
    let hadUpdateHint: Bool
  }

  private func requestPack(
    for festivalID: String, on socket: any PackSocket,
    onProgress: (@Sendable (PackDownloadProgress) -> Void)? = nil
  ) async throws -> Reply {
    let stored = try cache.load(festivalID)
    let generation = (requestGeneration[festivalID] ?? 0) + 1
    requestGeneration[festivalID] = generation
    let requestID = UUID().uuidString.lowercased()
    try await socket.send(PackWire.request(festivalID: festivalID, requestID: requestID, etag: stored?.etag))
    var hadUpdateHint = false
    while true {
      let message = try PackWire.decode(
        try await PackWire.receiveText(on: socket, timeoutNanoseconds: responseTimeoutNanoseconds)
      )
      if message.event == "pack.updated" {
        if message.data?["festivalId"] as? String == festivalID { hadUpdateHint = true }
        continue
      }
      guard message.requestID == requestID else { throw PackSyncError.invalidMessage }
      switch message.event {
      case "pack.snapshot":
        let updated = try PackWire.cachedPack(from: message, festivalID: festivalID)
        return Reply(result: try store(updated, generation: generation), hadUpdateHint: hadUpdateHint)
      case "pack.start":
        let (updated, chunkHint) = try await PackWire.chunkedPack(
          start: message, socket: socket, requestID: requestID, festivalID: festivalID,
          timeoutNanoseconds: responseTimeoutNanoseconds, onProgress: onProgress
        )
        return Reply(result: try store(updated, generation: generation), hadUpdateHint: hadUpdateHint || chunkHint)
      case "pack.not_modified":
        guard let stored, message.data?["festivalId"] as? String == festivalID,
              message.data?["packVersion"] as? Int == stored.packVersion,
              message.data?["etag"] as? String == stored.etag else {
          throw PackSyncError.invalidMessage
        }
        if generation < (committedGeneration[festivalID] ?? 0) {
          // 더 늦게 시작한 요청이나 삭제가 이미 반영됐다. 세대를 내리거나 지운 팩을 되살리지 않는다.
          guard let latest = try cache.load(festivalID) else { throw PackSyncError.packDeleted }
          return Reply(result: .notModified(latest), hadUpdateHint: hadUpdateHint)
        }
        try? cache.markChecked(festivalID)
        committedGeneration[festivalID] = generation
        return Reply(result: .notModified(try cache.load(festivalID) ?? stored), hadUpdateHint: hadUpdateHint)
      case "pack.retry":
        guard message.data?["festivalId"] as? String == festivalID,
              let milliseconds = message.data?["retryAfterMs"] as? Int,
              milliseconds > 0 else { throw PackSyncError.invalidMessage }
        return Reply(result: .retryAfter(TimeInterval(milliseconds) / 1000), hadUpdateHint: false)
      case "pack.error":
        guard let code = message.data?["code"] as? String else { throw PackSyncError.invalidMessage }
        if code == "PACK_BUSY", let milliseconds = message.data?["retryAfterMs"] as? Int,
           milliseconds > 0 {
          return Reply(result: .retryAfter(TimeInterval(milliseconds) / 1000), hadUpdateHint: false)
        }
        throw PackSyncError.server(code)
      default:
        throw PackSyncError.invalidMessage
      }
    }
  }

  private func store(_ updated: CachedFestivalPack, generation: Int) throws -> PackSyncResult {
    if generation < (committedGeneration[updated.festivalID] ?? 0) {
      guard let latest = try cache.load(updated.festivalID) else { throw PackSyncError.packDeleted }
      return .notModified(latest)
    }
    let saved = try cache.save(updated)
    committedGeneration[updated.festivalID] = generation
    return saved == updated ? .updated(saved) : .notModified(saved)
  }

  private func endpoint() throws -> URL {
    guard let baseURL, baseURL.scheme == "https", baseURL.host != nil,
          var parts = URLComponents(url: baseURL, resolvingAgainstBaseURL: false) else {
      throw baseURL == nil ? PackSyncError.unconfigured : PackSyncError.invalidEndpoint
    }
    parts.scheme = "wss"
    parts.path = "/api/v1/festivals/updates"
    parts.query = nil
    parts.fragment = nil
    guard let url = parts.url else { throw PackSyncError.invalidEndpoint }
    return url
  }

  private func isValidFestivalID(_ id: String) -> Bool {
    !id.isEmpty && id.count <= 128 && id.utf8.allSatisfy {
      ($0 >= 65 && $0 <= 90) || ($0 >= 97 && $0 <= 122) || ($0 >= 48 && $0 <= 57) || $0 == 45 || $0 == 95
    }
  }
}
