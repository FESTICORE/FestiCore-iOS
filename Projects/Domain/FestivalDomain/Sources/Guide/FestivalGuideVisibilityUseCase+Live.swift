import Dependencies
import FestivalDomainInterface

extension FestivalGuideVisibilityUseCaseDependency: DependencyKey {
  public static var liveValue: any FestivalGuideVisibilityUseCaseInterface {
    return FestivalGuideVisibilityUseCaseImpl()
  }
}
