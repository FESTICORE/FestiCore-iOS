import Dependencies
import FestivalDomainInterface

/// 공용 카탈로그 서비스를 통해 캐시와 온라인 상세를 조회한다.
public struct FestivalCatalogRepositoryImpl: FestivalCatalogRepositoryInterface {
  @Dependency(\.festivalCatalogService) private var catalogService

  public init() {}

  /// 기기에 저장된 축제 목록을 읽는다.
  public func cachedFestivals() async throws -> [FestivalCatalogItem] {
    return try await catalogService.cachedFestivals()
  }

  /// 서버에서 축제 목록을 다시 받아 저장한다.
  public func refreshFestivals() async throws -> [FestivalCatalogItem] {
    return try await catalogService.refresh()
  }

  public func festivalDetail(for festivalID: String) async throws -> FestivalPackDocument {
    return try await catalogService.festivalDetail(for: festivalID)
  }

  public func festivalPage(
    after: String?,
    limit: Int
  ) async throws -> FestivalCatalogPage {
    return try await catalogService.page(
      after: after,
      limit: limit
    )
  }
}
