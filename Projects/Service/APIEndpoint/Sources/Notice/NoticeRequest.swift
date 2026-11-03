//
//  NoticeRequest.swift
//  APIEndpoint
//

import Alamofire
import API
import FestiCoreNetworkInterface

public enum NoticeRequest: FestiCoreDataRequest, Sendable {
  case list
  case detail(id: String)

  public var path: String {
    switch self {
    case .list: NoticeAPI.list.path
    case let .detail(id): NoticeAPI.detail(id: id).path
    }
  }

  public var method: HTTPMethod { .get }
  public var authorization: FestiCoreAuthorization { .none }
  public var maxRetryAttempts: Int { 1 }
  public var parameters: (any Encodable & Sendable)? { nil }
}
