import Dependencies
import UserNotificationDomainInterface

extension UserNotificationRepositoryDependency: DependencyKey {
  public static var liveValue: any UserNotificationRepositoryInterface { UserNotificationRepositoryImpl() }
}

extension UserNotificationUseCaseDependency: DependencyKey {
  public static var liveValue: any UserNotificationUseCaseInterface { UserNotificationUseCaseImpl() }
}
