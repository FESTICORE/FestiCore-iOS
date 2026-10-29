import Foundation
import Dependencies

/// 검증과 디스크 저장을 마친 공개 팩. `pack`은 서버의 공개 팩 JSON이다.
public struct CachedFestivalPack: Sendable, Equatable {
  public let festivalID: String
  public let packVersion: Int
  public let etag: String
  public let pack: Data

  public init(festivalID: String, packVersion: Int, etag: String, pack: Data) {
    self.festivalID = festivalID
    self.packVersion = packVersion
    self.etag = etag
    self.pack = pack
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
  /// 연결이 끊어지면 `.reconnecting`을 알리고 저장된 ETag로 다시 요청한다.
  func updates(for festivalID: String) -> AsyncThrowingStream<PackSyncResult, Error>
}

public enum PackSyncServiceDependency: TestDependencyKey {
  public static var testValue: any PackSyncService { UnimplementedPackSyncService() }
}

public extension DependencyValues {
  var packSyncService: any PackSyncService {
    get { self[PackSyncServiceDependency.self] }
    set { self[PackSyncServiceDependency.self] = newValue }
  }
}

private struct UnimplementedPackSyncService: PackSyncService {
  func cachedPack(for _: String) async throws -> CachedFestivalPack? {
    fatalError("packSyncService 미등록")
  }

  func cachedPacks() async throws -> [CachedFestivalPack] {
    []
  }

  func sync(for _: String) async throws -> PackSyncResult {
    fatalError("packSyncService 미등록")
  }

  func updates(for _: String) -> AsyncThrowingStream<PackSyncResult, Error> {
    fatalError("packSyncService 미등록")
  }
}
