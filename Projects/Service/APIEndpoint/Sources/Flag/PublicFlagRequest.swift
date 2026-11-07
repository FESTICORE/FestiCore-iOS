//
//  PublicFlagRequest.swift
//  APIEndpoint
//
//  Created by FestiCore on 11/7/26.
//

import Alamofire
import API
import FestiCoreNetworkInterface
import Foundation

/// 누구나 볼 수 있는 깃발 조회 요청. 로그인 상태면 토큰을 붙여 팔로우·기수 여부를 함께 받는다.
public enum PublicFlagRequest: FestiCoreDataRequest, Sendable {
  case detail(flagID: String)

  public var path: String { return api.path }

  public var method: HTTPMethod { return .get }

  /// 서버가 30초 private 캐시를 허용하지만 팔로우 직후 상태가 늦게 보이지 않도록 매번 새로 받는다.
  public var cachePolicy: URLRequest.CachePolicy? { return .reloadIgnoringLocalCacheData }

  /// 익명이면 토큰 없이, 로그인 상태면 토큰을 붙여 보낸다.
  public var authorization: FestiCoreAuthorization { return .automatic }

  /// 토큰 문제는 재시도로 풀리지 않으므로 다른 깃발 요청처럼 재시도하지 않는다.
  public var maxRetryAttempts: Int { return 0 }

  public var parameters: (any Encodable & Sendable)? { return nil }

  private var api: FlagAPI {
    switch self {
    case let .detail(flagID): return .profile(flagID: flagID)
    }
  }
}
