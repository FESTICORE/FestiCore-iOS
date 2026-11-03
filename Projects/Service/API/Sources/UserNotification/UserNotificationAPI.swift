public enum UserNotificationAPI: Sendable {
  case list
  case unreadCount
  case read
  case delete

  public var path: String {
    let base = "\(FestiCoreDomain.me.path)/notifications"
    switch self {
    case .list: return base
    case .unreadCount: return "\(base)/unread-count"
    case .read: return "\(base)/read"
    case .delete: return "\(base)/delete"
    }
  }
}
