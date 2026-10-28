import Dependencies
import FestiCoreFestivalDomainInterface

extension FestivalCatalogServiceDependency: DependencyKey {
  public static var liveValue: any FestivalCatalogService {
    NetworkContainer.festivalCatalogService
  }
}
