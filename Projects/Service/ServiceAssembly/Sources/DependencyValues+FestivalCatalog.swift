import Dependencies
import FestiCoreFestivalCatalogInterface

extension FestivalCatalogServiceDependency: DependencyKey {
  public static var liveValue: any FestivalCatalogService {
    NetworkContainer.festivalCatalogService
  }
}
