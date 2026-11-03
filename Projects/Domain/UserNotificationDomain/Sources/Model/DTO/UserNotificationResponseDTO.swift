import FestiCoreNetworkInterface

typealias UserNotificationListResponseDTO = BaseResponseDTO<UserNotificationListDataDTO>
typealias UserNotificationCountResponseDTO = BaseResponseDTO<UserNotificationCountDataDTO>

struct UserNotificationListDataDTO: Decodable, Sendable {
  let items: [UserNotificationItemDTO]
  let nextCursor: String?
}

struct UserNotificationItemDTO: Decodable, Sendable {
  let id: String
  let type: String
  let festivalId: String?
  let title: String
  let body: String
  let createdAt: String
  let readAt: String?
  let route: String?
}

struct UserNotificationCountDataDTO: Decodable, Sendable {
  let unreadCount: Int
}
