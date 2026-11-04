import Foundation
import Dependencies

/// 검증과 디스크 저장을 마친 공개 팩. `pack`은 서버의 공개 팩 JSON이다.
public struct CachedFestivalPack: Sendable, Equatable {
  public let festivalID: String
  public let packVersion: Int
  public let etag: String
  public let pack: Data
  /// 서버와 마지막으로 버전을 맞춘 시각. 디스크에서 읽은 팩에만 있다.
  public let checkedAt: Date?

  public init(festivalID: String, packVersion: Int, etag: String, pack: Data, checkedAt: Date? = nil) {
    self.festivalID = festivalID
    self.packVersion = packVersion
    self.etag = etag
    self.pack = pack
    self.checkedAt = checkedAt
  }

  /// 확인 시각은 저장 메타데이터라 같은 팩인지 비교할 때 보지 않는다.
  public static func == (lhs: Self, rhs: Self) -> Bool {
    lhs.festivalID == rhs.festivalID && lhs.packVersion == rhs.packVersion
      && lhs.etag == rhs.etag && lhs.pack == rhs.pack
  }
}

public enum PackSyncResult: Sendable, Equatable {
  case updated(CachedFestivalPack)
  case notModified(CachedFestivalPack)
  case retryAfter(TimeInterval)
  case reconnecting
}

public struct PackDownloadProgress: Sendable, Equatable {
  public let receivedBytes: Int
  public let totalBytes: Int

  public init(receivedBytes: Int, totalBytes: Int) {
    self.receivedBytes = receivedBytes
    self.totalBytes = totalBytes
  }
}

public enum PackDownloadEvent: Sendable, Equatable {
  /// 서버 갱신 알림이나 재시도로 새 요청을 시작할 때 이전 요청의 바이트를 지운다.
  case reset
  case progress(PackDownloadProgress)
  /// 완성된 팩을 캐시에 저장하거나 기존 캐시를 검증한 뒤에만 보낸다.
  case finished(PackSyncResult)
}

public protocol PackSyncService: Sendable {
  func cachedPack(for festivalID: String) async throws -> CachedFestivalPack?
  /// 무결성 검증을 통과한 로컬 팩 목록. 네트워크에 연결하지 않는다.
  func cachedPacks() async throws -> [CachedFestivalPack]
  func sync(for festivalID: String) async throws -> PackSyncResult
  func download(for festivalID: String) -> AsyncThrowingStream<PackDownloadEvent, Error>
  /// 기기에 저장한 팩을 지운다. 없으면 아무것도 하지 않는다.
  func deletePack(for festivalID: String) async throws
  /// 연결이 끊어지면 `.reconnecting`을 알리고 저장된 ETag로 다시 요청한다.
  func updates(for festivalID: String) -> AsyncThrowingStream<PackSyncResult, Error>
}

public extension PackSyncService {
  func download(for _: String) -> AsyncThrowingStream<PackDownloadEvent, Error> {
    AsyncThrowingStream { $0.finish(throwing: TestPackSyncServiceUnavailable()) }
  }

  /// 삭제를 지원하지 않는 구현은 지우지 않았음을 오류로 알린다.
  func deletePack(for _: String) async throws {
    throw PackDeletionUnsupported()
  }
}

/// 이 `PackSyncService` 구현은 기기에 저장한 팩을 지울 수 없다.
public struct PackDeletionUnsupported: Error, Equatable {
  public init() {}
}

public enum PackSyncServiceDependency: TestDependencyKey {
  public static var testValue: any PackSyncService {
    return UnimplementedPackSyncService()
  }
}

public extension DependencyValues {
  var packSyncService: any PackSyncService {
    get {
      return self[PackSyncServiceDependency.self]
    }
    set { self[PackSyncServiceDependency.self] = newValue }
  }
}

private struct UnimplementedPackSyncService: PackSyncService {
  func cachedPack(for _: String) async throws -> CachedFestivalPack? {
    throw TestPackSyncServiceUnavailable()
  }

  func cachedPacks() async throws -> [CachedFestivalPack] {
    return []
  }

  func sync(for _: String) async throws -> PackSyncResult {
    throw TestPackSyncServiceUnavailable()
  }

  func deletePack(for _: String) async throws {
    reportIssue("packSyncService.deletePack 미등록")
    throw TestPackSyncServiceUnavailable()
  }

  func updates(for _: String) -> AsyncThrowingStream<PackSyncResult, Error> {
    return AsyncThrowingStream { continuation in
      continuation.finish(throwing: TestPackSyncServiceUnavailable())
    }
  }

  func download(for _: String) -> AsyncThrowingStream<PackDownloadEvent, Error> {
    AsyncThrowingStream { $0.finish(throwing: TestPackSyncServiceUnavailable()) }
  }
}

struct TestPackSyncServiceUnavailable: Error {}
