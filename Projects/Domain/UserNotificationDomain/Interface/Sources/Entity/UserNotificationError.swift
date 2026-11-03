public enum UserNotificationError: Error, Equatable, Sendable {
  case unauthenticated
  case invalidResponse
  case unavailable
}
