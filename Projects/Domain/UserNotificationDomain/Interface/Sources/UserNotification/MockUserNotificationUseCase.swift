import IssueReporting

public struct MockUserNotificationUseCase: UserNotificationUseCaseInterface {
  private let list: @Sendable (String?) async throws -> UserNotificationPage
  private let count: @Sendable () async throws -> Int
  private let read: @Sendable ([String]) async throws -> Void
  private let remove: @Sendable ([String]) async throws -> Void

  public init(
    notifications: @escaping @Sendable (String?) async throws -> UserNotificationPage = { _ in
      reportIssue("userNotificationUseCase 미등록")
      throw UserNotificationError.unavailable
    },
    unreadCount: @escaping @Sendable () async throws -> Int = {
      reportIssue("userNotificationUseCase 미등록")
      throw UserNotificationError.unavailable
    },
    markRead: @escaping @Sendable ([String]) async throws -> Void = { _ in
      reportIssue("userNotificationUseCase 미등록")
      throw UserNotificationError.unavailable
    },
    delete: @escaping @Sendable ([String]) async throws -> Void = { _ in
      reportIssue("userNotificationUseCase 미등록")
      throw UserNotificationError.unavailable
    }
  ) {
    list = notifications
    count = unreadCount
    read = markRead
    remove = delete
  }

  public func notifications(before: String?) async throws -> UserNotificationPage { try await list(before) }
  public func unreadCount() async throws -> Int { try await count() }
  public func markRead(ids: [String]) async throws { try await read(ids) }
  public func delete(ids: [String]) async throws { try await remove(ids) }
}
