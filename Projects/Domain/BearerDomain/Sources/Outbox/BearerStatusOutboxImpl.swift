//
//  BearerStatusOutboxImpl.swift
//  BearerDomain
//
//  Created by FestiCore on 11/3/26.
//

import BearerDomainInterface
import Dependencies
import FestiCoreAuthInterface
import Foundation
import os

/// 기수 상태 변경을 파일에 남겨 두고 누른 시각 순서대로 한 건씩 보낸다.
/// - 연결 없음: 5초마다 다시 보낸다. 429: 15초 뒤 다시 보낸다.
/// - 서버 오류: 2·4·8·16·32초 뒤 다시 보내고, 그래도 안 되면 멈추고 알린다.
/// - 401·약관 동의 필요: 멈추고 알린다. 대기열은 남긴다.
/// - 다른 계정으로 바뀌면 이전 계정의 대기열을 버린다.
public actor BearerStatusOutboxImpl: BearerStatusOutboxInterface {
  static let offlineDelay: Duration = .seconds(5)
  static let rateLimitDelay: Duration = .seconds(15)
  static let maxServerRetries = 5
  private static let logger = Logger(subsystem: "io.festiCore.co", category: "BearerStatusOutbox")

  struct Item: Equatable, Sendable {
    let flagID: String
    let ownerUserID: String
    let request: BearerStatusRequest
  }

  @Dependency(\.bearerRepository) private var repository
  @Dependency(\.authService) private var authService
  @Dependency(\.continuousClock) private var clock

  private let fileURL: URL?
  private var items: [Item] = []
  private var isLoaded = false
  private var worker: Task<Void, Never>?
  /// 지금 서버로 보내는 중인 건. 이 건 앞에는 새 변경을 끼워 넣지 않는다.
  private var inFlightID: String?
  private var subscribers: [UUID: (flagID: String, continuation: AsyncStream<BearerOutboxEvent>.Continuation)] = [:]

  /// - Parameter fileURL: 대기열을 남길 파일. nil이면 메모리에만 둔다.
  public init(fileURL: URL? = BearerStatusOutboxImpl.defaultFileURL) {
    self.fileURL = fileURL
  }

  public static var defaultFileURL: URL? {
    FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first?
      .appendingPathComponent("bearer-status-outbox.json")
  }

  /// 중간에 기다리지 않고 바로 넣는다. 탭마다 따로 불려 도착 순서가 바뀌어도 누른 시각 순서를 지킨다.
  public func enqueue(flagID: String, ownerUserID: String, request: BearerStatusRequest) {
    loadIfNeeded()
    let start = inFlightID == nil ? 0 : min(1, items.count)
    let index = items[start...].firstIndex { $0.request.clientAt > request.clientAt } ?? items.endIndex
    items.insert(Item(flagID: flagID, ownerUserID: ownerUserID, request: request), at: index)
    save()
    emitPending(flagID)
    startWorker()
  }

  public func pending(flagID: String) async -> [BearerStatusRequest] {
    loadIfNeeded()
    let currentUserID = await authService.currentUserID
    return items.filter { $0.flagID == flagID && $0.ownerUserID == currentUserID }.map(\.request)
  }

  public func events(flagID: String) -> AsyncStream<BearerOutboxEvent> {
    let (stream, continuation) = AsyncStream.makeStream(of: BearerOutboxEvent.self)
    let id = UUID()
    subscribers[id] = (flagID, continuation)
    continuation.onTermination = { _ in
      Task { await self.unsubscribe(id: id) }
    }
    return stream
  }

  public func resume() async {
    loadIfNeeded()
    startWorker()
  }
}

private extension BearerStatusOutboxImpl {
  func unsubscribe(id: UUID) {
    subscribers[id] = nil
  }

  func emit(_ event: BearerOutboxEvent, for flagID: String) {
    for subscriber in subscribers.values where subscriber.flagID == flagID {
      subscriber.continuation.yield(event)
    }
  }

  func emitPending(_ flagID: String) {
    emit(.pending(items.filter { $0.flagID == flagID }.map(\.request)), for: flagID)
  }

  func startWorker() {
    guard worker == nil, !items.isEmpty else { return }
    worker = Task { await self.run() }
  }

  func run() async {
    var serverFailures = 0
    while let item = items.first, !Task.isCancelled {
      guard let currentUserID = await authService.currentUserID else {
        emit(.needsLogin, for: item.flagID)
        break
      }
      guard item.ownerUserID == currentUserID else {
        // 다른 계정의 변경은 보내지 않고 버린다.
        let dropped = items.filter { $0.ownerUserID != currentUserID }
        items.removeAll { $0.ownerUserID != currentUserID }
        save()
        Set(dropped.map(\.flagID)).forEach(emitPending)
        continue
      }
      inFlightID = item.request.id
      defer { inFlightID = nil }
      do {
        let status = try await repository.sendStatus(flagID: item.flagID, request: item.request)
        remove(item)
        serverFailures = 0
        emit(.sent(id: item.request.id, status), for: item.flagID)
      } catch BearerError.offline {
        emit(.offline, for: item.flagID)
        guard await sleep(Self.offlineDelay) else { break }
      } catch BearerError.rateLimited {
        guard await sleep(Self.rateLimitDelay) else { break }
      } catch BearerError.notAuthenticated {
        emit(.needsLogin, for: item.flagID)
        break
      } catch BearerError.termsRequired {
        emit(.gaveUp(.termsRequired), for: item.flagID)
        break
      } catch is CancellationError {
        break
      } catch let error as BearerError where error != .unavailable && error != .invalidResponse {
        // 서버가 받지 않는 변경이면 뒤에 쌓인 같은 깃발의 변경도 그 상태를 전제로 하므로 함께 버린다.
        items.removeAll { $0.flagID == item.flagID }
        save()
        emitPending(item.flagID)
        emit(.rejected(error), for: item.flagID)
      } catch {
        serverFailures += 1
        guard serverFailures <= Self.maxServerRetries else {
          emit(.gaveUp(error as? BearerError ?? .unavailable), for: item.flagID)
          break
        }
        guard await sleep(.seconds(1 << serverFailures)) else { break }
      }
    }
    worker = nil
  }

  func remove(_ item: Item) {
    items.removeAll { $0.request.id == item.request.id && $0.flagID == item.flagID }
    save()
    emitPending(item.flagID)
  }

  /// 기다렸으면 true, 취소됐으면 false
  func sleep(_ duration: Duration) async -> Bool {
    do {
      try await clock.sleep(for: duration)
      return true
    } catch {
      return false
    }
  }

  func loadIfNeeded() {
    guard !isLoaded else { return }
    isLoaded = true
    guard let fileURL, FileManager.default.fileExists(atPath: fileURL.path) else { return }
    do {
      let records = try JSONDecoder().decode([BearerOutboxRecordDTO].self, from: Data(contentsOf: fileURL))
      items = records.compactMap(\.item) + items
    } catch {
      // 파일 내용(멱등키·존)은 남기지 않고 오류 종류만 남긴다.
      Self.logger.error("기수 대기열 파일을 읽지 못함: \(String(describing: type(of: error)), privacy: .public)")
    }
  }

  func save() {
    guard let fileURL else { return }
    let records = items.map(BearerOutboxRecordDTO.init)
    do {
      try FileManager.default.createDirectory(at: fileURL.deletingLastPathComponent(), withIntermediateDirectories: true)
      try JSONEncoder().encode(records).write(to: fileURL, options: [.atomic, .completeFileProtectionUntilFirstUserAuthentication])
    } catch {
      // 파일에 남기지 못해도 메모리 대기열로 전송은 이어 간다.
      Self.logger.error("기수 대기열 파일을 저장하지 못함: \(String(describing: type(of: error)), privacy: .public)")
    }
  }
}
