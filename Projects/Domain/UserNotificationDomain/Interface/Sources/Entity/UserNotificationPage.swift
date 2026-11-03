public struct UserNotificationPage: Equatable, Sendable {
  public let items: [UserNotificationItem]
  public let nextCursor: String?

  public init(items: [UserNotificationItem], nextCursor: String?) {
    self.items = items
    self.nextCursor = nextCursor
  }
}
