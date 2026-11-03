import FestiCoreUtility
import UserNotificationDomainInterface

extension UserNotificationListDataDTO {
  func toDomain() throws -> UserNotificationPage {
    try UserNotificationPage(items: items.map { try $0.toDomain() }, nextCursor: nextCursor)
  }
}

extension UserNotificationItemDTO {
  func toDomain() throws -> UserNotificationItem {
    guard let created = createdAt.isoDate,
          readAt == nil || readAt?.isoDate != nil else { throw UserNotificationError.invalidResponse }
    return UserNotificationItem(
      id: id,
      type: type,
      festivalID: festivalId,
      title: title,
      body: body,
      createdAt: created,
      readAt: readAt?.isoDate,
      route: route
    )
  }
}
