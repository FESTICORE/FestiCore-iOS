//
//  FlagAPI.swift
//  API
//
//  Created by FestiCore on 11/3/26.
//

/// 깃발 API 경로. 깃발 ID는 경로 한 칸으로 붙인다.
public enum FlagAPI: Sendable, Equatable {
  case profile(flagID: String)
  case report(flagID: String)
  case pinnedFlag
  case photo(flagID: String)
  case bearer(flagID: String)
  case status(flagID: String)
  case inviteCoBearer(flagID: String)
  case coBearer(flagID: String, userID: String)
  case claim
  /// 코드 없는 기수 등록
  case register
  /// 내가 기수인 깃발 목록
  case bearerFlags
  /// 내가 팔로우한 깃발 목록
  case follows

  public var path: String {
    switch self {
    case let .profile(flagID): return "\(FestiCoreDomain.flags.path)/\(flagID)"
    case let .report(flagID): return "\(FestiCoreDomain.flags.path)/\(flagID)/report"
    case .pinnedFlag: return "\(FestiCoreDomain.me.path)/pinned-flag"
    case let .photo(flagID): return "\(FestiCoreDomain.flags.path)/\(flagID)/photo"
    case let .bearer(flagID): return "\(FestiCoreDomain.flags.path)/\(flagID)/bearer"
    case let .status(flagID): return "\(FestiCoreDomain.flags.path)/\(flagID)/status"
    case let .inviteCoBearer(flagID): return "\(FestiCoreDomain.flags.path)/\(flagID)/co-bearers/invite"
    case let .coBearer(flagID, userID): return "\(FestiCoreDomain.flags.path)/\(flagID)/co-bearers/\(userID)"
    case .claim: return "\(FestiCoreDomain.bearer.path)/claim"
    case .register: return "\(FestiCoreDomain.bearer.path)/register"
    case .bearerFlags: return "\(FestiCoreDomain.me.path)/bearer-flags"
    case .follows: return "\(FestiCoreDomain.me.path)/follows"
    }
  }
}
