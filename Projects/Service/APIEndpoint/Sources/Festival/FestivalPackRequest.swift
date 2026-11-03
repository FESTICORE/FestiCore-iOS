//
//  FestivalPackRequest.swift
//  APIEndpoint
//
//  Created by FestiCore on 11/3/26.
//

import Alamofire
import API
import FestiCoreNetworkInterface

public enum FestivalPackRequest: FestiCoreDataRequest, Sendable {
  /// 앱에 저장된 버전(`from`)과 현재 발행 팩의 차이. 공개 API라 인증하지 않는다.
  case changes(festivalID: String, fromVersion: Int)

  public var path: String {
    switch self {
    case let .changes(festivalID, _): return FestivalAPI.packChanges(festivalID: festivalID).path
    }
  }

  public var method: HTTPMethod { .get }
  public var authorization: FestiCoreAuthorization { .none }
  public var maxRetryAttempts: Int { 1 }

  public var parameters: (any Encodable & Sendable)? {
    switch self {
    case let .changes(_, fromVersion): return PackChangesQuery(from: fromVersion)
    }
  }
}

private struct PackChangesQuery: Encodable, Sendable {
  let from: Int
}
