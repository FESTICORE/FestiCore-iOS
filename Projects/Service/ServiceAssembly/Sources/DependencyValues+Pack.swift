import Dependencies
import FestiCorePackInterface

extension PackSyncServiceDependency: DependencyKey {
  public static var liveValue: any PackSyncService {
    NetworkContainer.packSyncService
  }
}
