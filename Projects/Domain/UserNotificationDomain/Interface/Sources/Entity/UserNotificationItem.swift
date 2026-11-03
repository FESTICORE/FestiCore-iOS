import Foundation

public struct UserNotificationItem: Equatable, Identifiable, Sendable {
  public let id: String
  public let type: String
  public let festivalID: String?
  public let title: String
  public let body: String
  public let createdAt: Date
  public let readAt: Date?
  public let route: String?

  public init(
    id: String,
    type: String,
    festivalID: String?,
    title: String,
    body: String,
    createdAt: Date,
    readAt: Date?,
    route: String?
  ) {
    self.id = id
    self.type = type
    self.festivalID = festivalID
    self.title = title
    self.body = body
    self.createdAt = createdAt
    self.readAt = readAt
    self.route = route
  }
}
