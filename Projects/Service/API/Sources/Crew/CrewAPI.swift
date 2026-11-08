/// 크루 API 경로. 크루 ID와 사용자 ID는 경로 한 칸으로 붙인다.
public enum CrewAPI: Sendable, Equatable {
  case create
  case gather(String)
  case crew(String)
  case status(String)
  case rotateInvite(String)
  case member(
    crewID: String,
    userID: String
  )
  case transfer(String)
  case invite(code: String)
  case join

  public var path: String {
    switch self {
    case let .gather(id): return "api/v1/crews/\(id)/gather"
    case .create: return "api/v1/crews"
    case let .crew(id): return "api/v1/crews/\(id)"
    case let .status(id): return "api/v1/crews/\(id)/status"
    case let .rotateInvite(id): return "api/v1/crews/\(id)/invite/rotate"
    case let .member(
      crewID,
      userID
    ): return "api/v1/crews/\(crewID)/members/\(userID)"
    case let .transfer(id): return "api/v1/crews/\(id)/transfer"
    case let .invite(code): return "api/v1/crews/invite/\(code)"
    case .join: return "api/v1/crews/join"
    }
  }
}
