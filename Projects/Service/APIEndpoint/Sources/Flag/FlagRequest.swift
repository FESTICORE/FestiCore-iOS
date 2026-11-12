//
//  FlagRequest.swift
//  APIEndpoint
//
//  Created by FestiCore on 11/3/26.
//

import Alamofire
import API
import FestiCoreNetworkInterface
import Foundation

/// 기수 전용 요청. 모두 쓰기 또는 개인 응답이라 로그인 세션에 묶고 재시도하지 않는다.
public enum FlagRequest: FestiCoreDataRequest, Sendable {
  case bearer(flagID: String, sessionID: UUID)
  case updateProfile(flagID: String, body: FlagProfileBody, sessionID: UUID)
  case status(flagID: String, body: FlagStatusBody, idempotencyKey: String, sessionID: UUID)
  case inviteCoBearer(flagID: String, sessionID: UUID)
  case removeCoBearer(flagID: String, userID: String, sessionID: UUID)
  case claim(body: BearerClaimBody, deviceID: String, sessionID: UUID)
  /// 코드 없는 기수 등록. 재시도할 때도 같은 멱등키와 같은 본문을 보낸다.
  case register(
    body: BearerRegisterBody,
    idempotencyKey: String,
    sessionID: UUID
  )
  /// 내가 기수인 깃발 목록. 페스티벌을 주면 그 페스티벌 것만 받는다.
  case bearerFlags(
    query: BearerFlagsQuery,
    sessionID: UUID
  )
  /// 내 대표 깃발. 없으면 `flag`가 null이다.
  case pinnedFlag(sessionID: UUID)

  public var path: String { return api.path }

  public var method: HTTPMethod {
    switch self {
    case .bearer, .bearerFlags, .pinnedFlag: return .get
    case .updateProfile: return .patch
    case .status, .inviteCoBearer, .claim, .register: return .post
    case .removeCoBearer: return .delete
    }
  }

  public var headers: HTTPHeaders {
    switch self {
    case let .status(_, _, idempotencyKey, _): return ["Idempotency-Key": idempotencyKey]
    case let .claim(_, deviceID, _): return ["X-Device-Id": deviceID]
    case let .register(_, idempotencyKey, _):
      return ["Idempotency-Key": idempotencyKey]
    case .bearer, .updateProfile, .inviteCoBearer, .removeCoBearer, .bearerFlags, .pinnedFlag: return [:]
    }
  }

  /// 기수 상세·기수 깃발·대표 깃발은 서버가 `no-store`로 내려 준다. 로컬 캐시도 쓰지 않는다.
  public var cachePolicy: URLRequest.CachePolicy? {
    switch self {
    case .bearer, .bearerFlags, .pinnedFlag: return .reloadIgnoringLocalCacheData
    default: return nil
    }
  }

  public var authorization: FestiCoreAuthorization {
    switch self {
    case let .bearer(_, sessionID),
         let .updateProfile(_, _, sessionID),
         let .status(_, _, _, sessionID),
         let .inviteCoBearer(_, sessionID),
         let .removeCoBearer(_, _, sessionID),
         let .claim(_, _, sessionID):
      return .sessionBound(sessionID)
    case let .register(_, _, sessionID):
      return .sessionBound(sessionID)
    case let .bearerFlags(_, sessionID):
      return .sessionBound(sessionID)
    case let .pinnedFlag(sessionID):
      return .sessionBound(sessionID)
    }
  }

  public var maxRetryAttempts: Int { return 0 }

  public var parameters: (any Encodable & Sendable)? {
    switch self {
    case let .updateProfile(_, body, _): return body
    case let .status(_, body, _, _): return body
    case let .claim(body, _, _): return body
    case let .register(body, _, _):
      return body
    case let .bearerFlags(query, _):
      return query
    case .bearer, .inviteCoBearer, .removeCoBearer, .pinnedFlag: return nil
    }
  }

  private var api: FlagAPI {
    switch self {
    case let .bearer(flagID, _): return .bearer(flagID: flagID)
    case let .updateProfile(flagID, _, _): return .profile(flagID: flagID)
    case let .status(flagID, _, _, _): return .status(flagID: flagID)
    case let .inviteCoBearer(flagID, _): return .inviteCoBearer(flagID: flagID)
    case let .removeCoBearer(flagID, userID, _): return .coBearer(flagID: flagID, userID: userID)
    case .claim: return .claim
    case .register: return .register
    case .bearerFlags: return .bearerFlags
    case .pinnedFlag: return .pinnedFlag
    }
  }
}
