import Dependencies

public enum FestivalCatalogServiceDependency: TestDependencyKey {
  public static var testValue: any FestivalCatalogService { EmptyFestivalCatalogService() }
}

public extension DependencyValues {
  var festivalCatalogService: any FestivalCatalogService {
    get { self[FestivalCatalogServiceDependency.self] }
    set { self[FestivalCatalogServiceDependency.self] = newValue }
  }
}

private struct EmptyFestivalCatalogService: FestivalCatalogService {
  func cachedFestivals() async throws -> [FestivalCatalogItem] {
    []
  }

  func refresh() async throws -> [FestivalCatalogItem] {
    []
  }
}
