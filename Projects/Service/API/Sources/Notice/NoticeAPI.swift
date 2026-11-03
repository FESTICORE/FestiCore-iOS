//
//  NoticeAPI.swift
//  API
//

public enum NoticeAPI: Sendable {
  case list
  case detail(id: String)

  public var path: String {
    switch self {
    case .list: FestiCoreDomain.notices.path
    case let .detail(id): "\(FestiCoreDomain.notices.path)/\(id)"
    }
  }
}
