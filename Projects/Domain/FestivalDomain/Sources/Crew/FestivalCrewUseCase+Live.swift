import Dependencies
import FestivalDomainInterface

extension FestivalCrewUseCaseDependency: DependencyKey {
  public static var liveValue: any FestivalCrewUseCaseInterface { return FestivalCrewUseCaseImpl() }
}
