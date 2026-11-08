import Alamofire
import API
import FestiCoreNetworkInterface
import Foundation

public struct CrewCreateBody: Encodable, Sendable, Equatable {
  public let festivalId: String
  public let name: String
  public let nickname: String?

  public init(
    festivalId: String,
    name: String,
    nickname: String? = nil
  ) {
    self.festivalId = festivalId
    self.name = name
    self.nickname = nickname
  }
}

/// 내 상태 공유. `zoneId`가 없으면 서버는 존을 바꾸지 않는다.
public struct CrewStatusBody: Encodable, Sendable, Equatable {
  public let zoneId: String?
  public let state: String
  public let clientAt: String

  public init(
    zoneId: String?,
    state: String,
    clientAt: String
  ) {
    self.zoneId = zoneId
    self.state = state
    self.clientAt = clientAt
  }
}

public struct CrewRenameBody: Encodable, Sendable, Equatable {
  public let name: String

  public init(name: String) { self.name = name }
}

public struct CrewTransferBody: Encodable, Sendable, Equatable {
  public let toUserId: String

  public init(toUserId: String) { self.toUserId = toUserId }
}

public struct CrewJoinBody: Encodable, Sendable, Equatable {
  public let inviteCode: String

  public init(inviteCode: String) { self.inviteCode = inviteCode }
}

/// 크루 요청. 초대 미리보기만 로그인 없이 보내고, 나머지는 로그인 세션에 묶고 재시도하지 않는다.
public enum CrewRequest: FestiCoreDataRequest, Sendable {
  case create(body: CrewCreateBody, sessionID: UUID)
  case detail(crewID: String, sessionID: UUID)
  case status(crewID: String, body: CrewStatusBody, idempotencyKey: String, sessionID: UUID)
  case rotateInvite(crewID: String, sessionID: UUID)
  case rename(crewID: String, body: CrewRenameBody, sessionID: UUID)
  case removeMember(crewID: String, userID: String, sessionID: UUID)
  case transfer(crewID: String, body: CrewTransferBody, sessionID: UUID)
  case dissolve(crewID: String, sessionID: UUID)
  case invite(code: String)
  case join(body: CrewJoinBody, sessionID: UUID)

  public var path: String { return api.path }

  public var method: HTTPMethod {
    switch self {
    case .detail, .invite: return .get
    case .create, .status, .rotateInvite, .transfer, .join: return .post
    case .rename: return .patch
    case .removeMember, .dissolve: return .delete
    }
  }

  public var headers: HTTPHeaders {
    switch self {
    case .status(_, _, let idempotencyKey, _): return ["Idempotency-Key": idempotencyKey]
    default: return [:]
    }
  }

  /// 크루 상세는 서버가 `no-store`로 내려 준다. 로컬 캐시도 쓰지 않는다.
  public var cachePolicy: URLRequest.CachePolicy? {
    switch self {
    case .detail: return .reloadIgnoringLocalCacheData
    default: return nil
    }
  }

  public var maxRetryAttempts: Int { return 0 }

  public var authorization: FestiCoreAuthorization {
    switch self {
    case .create(_, let sessionID): return .sessionBound(sessionID)
    case .detail(_, let sessionID): return .sessionBound(sessionID)
    case .status(_, _, _, let sessionID): return .sessionBound(sessionID)
    case .rotateInvite(_, let sessionID): return .sessionBound(sessionID)
    case .rename(_, _, let sessionID): return .sessionBound(sessionID)
    case .removeMember(_, _, let sessionID): return .sessionBound(sessionID)
    case .transfer(_, _, let sessionID): return .sessionBound(sessionID)
    case .dissolve(_, let sessionID): return .sessionBound(sessionID)
    case .join(_, let sessionID): return .sessionBound(sessionID)
    case .invite: return .none
    }
  }

  public var parameters: (any Encodable & Sendable)? {
    switch self {
    case .create(let body, _): return body
    case .status(_, let body, _, _): return body
    case .rename(_, let body, _): return body
    case .transfer(_, let body, _): return body
    case .join(let body, _): return body
    case .detail, .rotateInvite, .removeMember, .dissolve, .invite: return nil
    }
  }

  private var api: CrewAPI {
    switch self {
    case .create: return .create
    case .detail(let crewID, _): return .crew(crewID)
    case .rename(let crewID, _, _): return .crew(crewID)
    case .dissolve(let crewID, _): return .crew(crewID)
    case .status(let crewID, _, _, _): return .status(crewID)
    case .rotateInvite(let crewID, _): return .rotateInvite(crewID)
    case .removeMember(let crewID, let userID, _):
      return .member(
        crewID: crewID,
        userID: userID
      )
    case .transfer(let crewID, _, _): return .transfer(crewID)
    case let .invite(code): return .invite(code: code)
    case .join: return .join
    }
  }
}
