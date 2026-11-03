import Dependencies

public protocol UserNotificationUseCaseInterface: Sendable {
  func notifications(before: String?) async throws -> UserNotificationPage
  func unreadCount() async throws -> Int
  func markRead(ids: [String]) async throws
  func delete(ids: [String]) async throws
}

public enum UserNotificationUseCaseDependency: TestDependencyKey {
  public static var testValue: any UserNotificationUseCaseInterface { MockUserNotificationUseCase() }
  public static var previewValue: any UserNotificationUseCaseInterface { testValue }
}

public extension DependencyValues {
  var userNotificationUseCase: any UserNotificationUseCaseInterface {
    get { self[UserNotificationUseCaseDependency.self] }
    set { self[UserNotificationUseCaseDependency.self] = newValue }
  }
}
