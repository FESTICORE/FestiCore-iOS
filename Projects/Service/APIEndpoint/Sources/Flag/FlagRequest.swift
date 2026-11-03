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

/// `POST flags/:flagId/status` 본문. 값이 없는 키는 보내지 않는다.
public struct FlagStatusBody: Encodable, Sendable, Equatable {
  public let clientAt: String
  public let zoneId: String?
  public let activity: String?
  public let status: String?
  public let restart: Bool?

  public init(clientAt: String, zoneId: String? = nil, activity: String? = nil, status: String? = nil, restart: Bool? = nil) {
    self.clientAt = clientAt
    self.zoneId = zoneId
    self.activity = activity
    self.status = status
    self.restart = restart
  }
}

/// `PATCH flags/:flagId` 본문. 화면의 전체 프로필을 보내며 비운 소개·존은 null로 지운다.
public struct FlagProfileBody: Encodable, Sendable, Equatable {
  public let name: String
  public let bio: String?
  public let tags: [String]
  public let planVisible: Bool
  public let homeZoneId: String?

  public init(name: String, bio: String?, tags: [String], planVisible: Bool, homeZoneId: String?) {
    self.name = name
    self.bio = bio
    self.tags = tags
    self.planVisible = planVisible
    self.homeZoneId = homeZoneId
  }

  private enum CodingKeys: String, CodingKey {
    case name, bio, tags, planVisible, homeZoneId
  }

  public func encode(to encoder: any Encoder) throws {
    var container = encoder.container(keyedBy: CodingKeys.self)
    try container.encode(name, forKey: .name)
    try container.encode(bio, forKey: .bio)
    try container.encode(tags, forKey: .tags)
    try container.encode(planVisible, forKey: .planVisible)
    try container.encode(homeZoneId, forKey: .homeZoneId)
  }
}

/// `POST bearer/claim` 본문
public struct BearerClaimBody: Encodable, Sendable, Equatable {
  public let festivalId: String
  public let code: String

  public init(festivalId: String, code: String) {
    self.festivalId = festivalId
    self.code = code
  }
}

/// 기수 전용 요청. 모두 쓰기 또는 개인 응답이라 로그인 세션에 묶고 재시도하지 않는다.
public enum FlagRequest: FestiCoreDataRequest, Sendable {
  case bearer(flagID: String, sessionID: UUID)
  case updateProfile(flagID: String, body: FlagProfileBody, sessionID: UUID)
  case status(flagID: String, body: FlagStatusBody, idempotencyKey: String, sessionID: UUID)
  case inviteCoBearer(flagID: String, sessionID: UUID)
  case removeCoBearer(flagID: String, userID: String, sessionID: UUID)
  case claim(body: BearerClaimBody, deviceID: String, sessionID: UUID)

  public var path: String { return api.path }

  public var method: HTTPMethod {
    switch self {
    case .bearer: return .get
    case .updateProfile: return .patch
    case .status, .inviteCoBearer, .claim: return .post
    case .removeCoBearer: return .delete
    }
  }

  public var headers: HTTPHeaders {
    switch self {
    case let .status(_, _, idempotencyKey, _): return ["Idempotency-Key": idempotencyKey]
    case let .claim(_, deviceID, _): return ["X-Device-Id": deviceID]
    case .bearer, .updateProfile, .inviteCoBearer, .removeCoBearer: return [:]
    }
  }

  /// 기수 상세는 서버가 `no-store`로 내려 준다. 로컬 캐시도 쓰지 않는다.
  public var cachePolicy: URLRequest.CachePolicy? {
    switch self {
    case .bearer: return .reloadIgnoringLocalCacheData
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
    }
  }

  public var maxRetryAttempts: Int { return 0 }

  public var parameters: (any Encodable & Sendable)? {
    switch self {
    case let .updateProfile(_, body, _): return body
    case let .status(_, body, _, _): return body
    case let .claim(body, _, _): return body
    case .bearer, .inviteCoBearer, .removeCoBearer: return nil
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
    }
  }
}

/// `POST flags/:flagId/photo` multipart 업로드. 파일 필드 이름은 `photo`다.
public struct FlagPhotoUploadRequest<Response: Decodable & Sendable>: FestiCoreUploadRequest, Sendable {
  public static var fieldName: String { "photo" }

  public let flagID: String
  public let imageData: Data
  public let mimeType: String
  public let fileName: String
  public let sessionID: UUID

  public init(flagID: String, imageData: Data, mimeType: String = "image/jpeg", fileName: String = "photo.jpg", sessionID: UUID) {
    self.flagID = flagID
    self.imageData = imageData
    self.mimeType = mimeType
    self.fileName = fileName
    self.sessionID = sessionID
  }

  public var path: String { FlagAPI.photo(flagID: flagID).path }
  public var method: HTTPMethod { .post }
  public var authorization: FestiCoreAuthorization { .sessionBound(sessionID) }
  public var maxRetryAttempts: Int { 0 }
  /// 셀룰러에서 5MB를 올릴 수 있게 기본보다 길게 기다린다.
  public var timeoutInterval: TimeInterval? { 60 }

  public var parts: [FestiCoreMultipartPart] {
    [FestiCoreMultipartPart(name: Self.fieldName, source: .data(imageData), fileName: fileName, mimeType: mimeType)]
  }
}
