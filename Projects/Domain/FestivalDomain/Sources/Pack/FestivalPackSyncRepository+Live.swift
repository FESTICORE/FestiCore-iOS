import Dependencies
import FestivalDomainInterface

extension FestivalPackSyncRepositoryDependency: DependencyKey {
  public static var liveValue: any FestivalPackSyncRepositoryInterface {
    return FestivalPackSyncRepositoryImpl()
  }
}
