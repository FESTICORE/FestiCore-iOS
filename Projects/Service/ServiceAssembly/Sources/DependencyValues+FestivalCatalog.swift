import Dependencies
import FestivalDomainInterface

extension FestivalCatalogServiceDependency: DependencyKey {
  public static var liveValue: any FestivalCatalogService {
    NetworkContainer.festivalCatalogService
  }
}
