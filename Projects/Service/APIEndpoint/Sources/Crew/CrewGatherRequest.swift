import Alamofire
import API
import FestiCoreNetworkInterface
import Foundation

public struct CrewGatherBody: Encodable, Sendable {
  public let zoneId: String
  public init(zoneId: String) { self.zoneId = zoneId }
}

/// 집결은 중복 알림을 막기 위해 자동 재시도하지 않는다.
public struct CrewGatherRequest: FestiCoreDataRequest, Sendable {
  public let crewID: String
  public let body: CrewGatherBody
  public let sessionID: UUID

  public init(
    crewID: String,
    body: CrewGatherBody,
    sessionID: UUID
  ) {
    self.crewID = crewID
    self.body = body
    self.sessionID = sessionID
  }

  public var path: String { return CrewAPI.gather(crewID).path }
  public var method: HTTPMethod { return .post }
  public var maxRetryAttempts: Int { return 0 }
  public var authorization: FestiCoreAuthorization { return .sessionBound(sessionID) }
  public var parameters: (any Encodable & Sendable)? { return body }
}

public struct CrewGatherResponseBody: Encodable, Sendable, Equatable {
  /// `going`(가는 중) 또는 `ack`(확인)
  public let response: String

  public init(response: String) { self.response = response }
}

/// 모여 응답. 서버가 덮어쓰지만 사용자가 다시 누를 수 있으므로 자동 재시도하지 않는다.
public struct CrewGatherResponseRequest: FestiCoreDataRequest, Sendable {
  public let crewID: String
  public let gatherID: String
  public let body: CrewGatherResponseBody
  public let sessionID: UUID

  public init(
    crewID: String,
    gatherID: String,
    body: CrewGatherResponseBody,
    sessionID: UUID
  ) {
    self.crewID = crewID
    self.gatherID = gatherID
    self.body = body
    self.sessionID = sessionID
  }

  public var path: String {
    return CrewAPI.gatherResponse(
      crewID: crewID,
      gatherID: gatherID
    ).path
  }
  public var method: HTTPMethod { return .post }
  public var maxRetryAttempts: Int { return 0 }
  public var authorization: FestiCoreAuthorization { return .sessionBound(sessionID) }
  public var parameters: (any Encodable & Sendable)? { return body }
}
