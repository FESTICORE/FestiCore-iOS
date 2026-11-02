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

public protocol PackSyncService: Sendable {
  func cachedPack(for festivalID: String) async throws -> CachedFestivalPack?
  /// 무결성 검증을 통과한 로컬 팩 목록. 네트워크에 연결하지 않는다.
  func cachedPacks() async throws -> [CachedFestivalPack]
  func sync(for festivalID: String) async throws -> PackSyncResult
  /// 기기에 저장한 팩을 지운다. 없으면 아무것도 하지 않는다.
  func deletePack(for festivalID: String) async throws
  /// 연결이 끊어지면 `.reconnecting`을 알리고 저장된 ETag로 다시 요청한다.
  func updates(for festivalID: String) -> AsyncThrowingStream<PackSyncResult, Error>
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
    throw TestPackSyncServiceUnavailable()
  }

  func updates(for _: String) -> AsyncThrowingStream<PackSyncResult, Error> {
    return AsyncThrowingStream { continuation in
      continuation.finish(throwing: TestPackSyncServiceUnavailable())
    }
  }
}

struct TestPackSyncServiceUnavailable: Error {}
