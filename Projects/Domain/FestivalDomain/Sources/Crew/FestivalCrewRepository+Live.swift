import Dependencies
import FestivalDomainInterface

extension FestivalCrewRepositoryDependency: DependencyKey {
  public static var liveValue: any FestivalCrewRepositoryInterface { return FestivalCrewRepositoryImpl() }
}
