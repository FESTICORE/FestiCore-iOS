import Dependencies
import UserNotificationDomainInterface

public struct UserNotificationUseCaseImpl: UserNotificationUseCaseInterface {
  @Dependency(\.userNotificationRepository) private var repository

  public init() {}

  public func notifications(before: String?) async throws -> UserNotificationPage {
    try await repository.notifications(before: before)
  }

  public func unreadCount() async throws -> Int { try await repository.unreadCount() }
  public func markRead(ids: [String]) async throws { try await repository.markRead(ids: ids) }
  public func delete(ids: [String]) async throws { try await repository.delete(ids: ids) }
}
