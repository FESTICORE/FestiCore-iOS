import Dependencies
import FestiCorePackInterface
import FestivalDomainInterface

public struct FestivalPackSyncRepositoryImpl: FestivalPackSyncRepositoryInterface {
  @Dependency(\.packSyncService) private var packService

  public init() {}

  /// 무결성 검증을 마친 로컬 팩 목록을 읽는다.
  public func cachedPacks() async throws -> [CachedFestivalPack] {
    return try await packService.cachedPacks()
  }

  /// 서버의 팩 변경을 계속 수신하고 재연결 상태를 전한다.
  public func packUpdates(for festivalID: String) -> AsyncThrowingStream<PackSyncResult, Error> {
    return packService.updates(for: festivalID)
  }

  /// 요청한 팩의 다운로드 진행과 저장 결과를 전한다.
  public func downloadPack(for festivalID: String) -> AsyncThrowingStream<PackDownloadEvent, Error>
  {
    return packService.download(for: festivalID)
  }
}
