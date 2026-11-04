import Dependencies

/// 축제 목록의 로컬 캐시와 서버 조회 계약.
public protocol FestivalCatalogRepositoryInterface: Sendable {
  /// 기기에 저장된 축제 목록을 읽는다.
  func cachedFestivals() async throws -> [FestivalCatalogItem]
  /// 서버에서 축제 목록을 다시 받아 저장한다.
  func refreshFestivals() async throws -> [FestivalCatalogItem]
  func festivalPage(
    after: String?,
    limit: Int
  ) async throws -> FestivalCatalogPage
}

public extension FestivalCatalogRepositoryInterface {
  func festivalPage(
    after: String?,
    limit: Int
  ) async throws -> FestivalCatalogPage {
    return FestivalCatalogPage(items: try await refreshFestivals(), nextCursor: nil)
  }
}

public enum FestivalCatalogRepositoryDependency: TestDependencyKey {
  public static var testValue: any FestivalCatalogRepositoryInterface {
    return UnregisteredFestivalCatalogRepository()
  }
  public static var previewValue: any FestivalCatalogRepositoryInterface { return testValue }
}

extension DependencyValues {
  public var festivalCatalogRepository: any FestivalCatalogRepositoryInterface {
    get { self[FestivalCatalogRepositoryDependency.self] }
    set { self[FestivalCatalogRepositoryDependency.self] = newValue }
  }
}

private struct UnregisteredFestivalCatalogRepository: FestivalCatalogRepositoryInterface {
  func cachedFestivals() async throws -> [FestivalCatalogItem] {
    reportIssue("festivalCatalogRepository.cachedFestivals 미등록")
    throw FestivalPackError.notRegistered
  }

  func refreshFestivals() async throws -> [FestivalCatalogItem] {
    reportIssue("festivalCatalogRepository.refreshFestivals 미등록")
    throw FestivalPackError.notRegistered
  }
}
