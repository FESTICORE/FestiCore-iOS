import Dependencies
import FestivalDomainInterface

extension FestivalFlagFollowServiceDependency: DependencyKey {
  public static var liveValue: any FestivalFlagFollowService {
    NetworkContainer.festivalFlagFollowService
  }
}
