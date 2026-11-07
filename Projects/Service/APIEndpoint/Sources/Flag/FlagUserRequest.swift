//
//  FlagUserRequest.swift
//  APIEndpoint
//
//  Created by FestiCore on 11/8/26.
//

import Alamofire
import API
import FestiCoreNetworkInterface
import Foundation

/// 로그인한 팔로워가 깃발 상세에서 보내는 쓰기 요청. 결과가 중복되면 안 되므로 재시도하지 않는다.
public enum FlagUserRequest: FestiCoreDataRequest, Sendable {
  case report(
    flagID: String,
    body: FlagReportBody
  )
  case pinnedFlag(body: PinnedFlagBody)

  public var path: String { return api.path }

  public var method: HTTPMethod {
    switch self {
    case .report: return .post
    case .pinnedFlag: return .put
    }
  }

  /// 로그인 토큰을 붙이고 만료되면 갱신한다. 토큰이 없으면 서버가 401로 로그인 필요를 알린다.
  public var authorization: FestiCoreAuthorization { return .automatic }

  public var maxRetryAttempts: Int { return 0 }

  public var parameters: (any Encodable & Sendable)? {
    switch self {
    case let .report(
      _,
      body
    ): return body
    case let .pinnedFlag(body): return body
    }
  }

  private var api: FlagAPI {
    switch self {
    case let .report(
      flagID,
      _
    ): return .report(flagID: flagID)
    case .pinnedFlag: return .pinnedFlag
    }
  }
}
