import Alamofire
import API
import FestiCoreNetworkInterface
import Foundation

public struct UserNotificationIDsBody: Encodable, Equatable, Sendable {
  public let ids: [String]

  public init(ids: [String]) { self.ids = ids }
}

public enum UserNotificationRequest: FestiCoreDataRequest, Sendable {
  case list(before: String?, sessionID: UUID)
  case unreadCount(sessionID: UUID)
  case read(body: UserNotificationIDsBody, sessionID: UUID)
  case delete(body: UserNotificationIDsBody, sessionID: UUID)

  public var path: String {
    switch self {
    case .list: return UserNotificationAPI.list.path
    case .unreadCount: return UserNotificationAPI.unreadCount.path
    case .read: return UserNotificationAPI.read.path
    case .delete: return UserNotificationAPI.delete.path
    }
  }

  public var method: HTTPMethod {
    switch self {
    case .list, .unreadCount: return .get
    case .read, .delete: return .post
    }
  }

  public var authorization: FestiCoreAuthorization {
    switch self {
    case let .list(_, sessionID), let .unreadCount(sessionID),
         let .read(_, sessionID), let .delete(_, sessionID):
      return .sessionBound(sessionID)
    }
  }

  public var cachePolicy: URLRequest.CachePolicy? { .reloadIgnoringLocalCacheData }
  public var maxRetryAttempts: Int { 0 }

  public var parameters: (any Encodable & Sendable)? {
    switch self {
    case let .list(before, _):
      guard let before else { return nil }
      return CursorQuery(before: before)
    case .unreadCount:
      return nil
    case let .read(body, _), let .delete(body, _):
      return body
    }
  }
}

private struct CursorQuery: Encodable, Sendable {
  let before: String
}
