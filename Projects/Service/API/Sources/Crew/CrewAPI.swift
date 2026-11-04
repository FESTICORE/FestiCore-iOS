public enum CrewAPI: Sendable, Equatable {
  case create

  public var path: String {
    switch self {
    case .create: return "api/v1/crews"
    }
  }
}
