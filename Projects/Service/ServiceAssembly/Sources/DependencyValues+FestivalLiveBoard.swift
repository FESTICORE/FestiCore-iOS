import Dependencies
import FestivalDomainInterface

extension FestivalLiveBoardServiceDependency: DependencyKey {
  public static var liveValue: any FestivalLiveBoardService {
    NetworkContainer.festivalLiveBoardService
  }
}
