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

public enum CrewRequest: FestiCoreDataRequest, Sendable {
  case create(body: CrewCreateBody, sessionID: UUID)

  public var path: String { return CrewAPI.create.path }
  public var method: HTTPMethod { return .post }
  public var maxRetryAttempts: Int { return 0 }

  public var authorization: FestiCoreAuthorization {
    switch self {
    case let .create(
      _,
      sessionID
    ): return .sessionBound(sessionID)
    }
  }

  public var parameters: (any Encodable & Sendable)? {
    switch self {
    case let .create(
      body,
      _
    ): return body
    }
  }
}
