import Dependencies

public protocol UserNotificationRepositoryInterface: Sendable {
  func notifications(before: String?) async throws -> UserNotificationPage
  func unreadCount() async throws -> Int
  func markRead(ids: [String]) async throws
  func delete(ids: [String]) async throws
}

public enum UserNotificationRepositoryDependency: TestDependencyKey {
  public static var testValue: any UserNotificationRepositoryInterface { MockUserNotificationRepository() }
  public static var previewValue: any UserNotificationRepositoryInterface { testValue }
}

public extension DependencyValues {
  var userNotificationRepository: any UserNotificationRepositoryInterface {
    get { self[UserNotificationRepositoryDependency.self] }
    set { self[UserNotificationRepositoryDependency.self] = newValue }
  }
}
