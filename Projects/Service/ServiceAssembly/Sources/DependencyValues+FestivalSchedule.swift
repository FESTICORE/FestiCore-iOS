import Dependencies
import FestivalDomainInterface

extension FestivalScheduleServiceDependency: DependencyKey {
  public static var liveValue: any FestivalScheduleService {
    NetworkContainer.festivalScheduleService
  }
}
