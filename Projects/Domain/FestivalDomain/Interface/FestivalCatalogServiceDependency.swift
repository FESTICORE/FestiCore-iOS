import Dependencies

public enum FestivalCatalogServiceDependency: TestDependencyKey {
  public static var testValue: any FestivalCatalogService { UnimplementedFestivalCatalogService() }
}

public extension DependencyValues {
  var festivalCatalogService: any FestivalCatalogService {
    get { self[FestivalCatalogServiceDependency.self] }
    set { self[FestivalCatalogServiceDependency.self] = newValue }
  }
}

private struct UnimplementedFestivalCatalogService: FestivalCatalogService {
  func cachedFestivals() async throws -> [FestivalCatalogItem] {
    fatalError("festivalCatalogService 미등록")
  }

  func refresh() async throws -> [FestivalCatalogItem] {
    fatalError("festivalCatalogService 미등록")
  }
}
