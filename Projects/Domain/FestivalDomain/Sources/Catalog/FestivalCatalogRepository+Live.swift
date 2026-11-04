import Dependencies
import FestivalDomainInterface

extension FestivalCatalogRepositoryDependency: DependencyKey {
  public static var liveValue: any FestivalCatalogRepositoryInterface {
    return FestivalCatalogRepositoryImpl()
  }
}
