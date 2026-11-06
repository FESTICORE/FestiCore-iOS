public enum CrewAPI: Sendable, Equatable {
  case create
  case gather(String)

  public var path: String {
    switch self {
    case let .gather(id): return "api/v1/crews/\(id)/gather"
    case .create: return "api/v1/crews"
    }
  }
}
