//
//  FestivalAPI.swift
//  API
//
//  Created by FestiCore on 11/3/26.
//

public enum FestivalAPI: Sendable {
  /// 받은 팩과 현재 발행 팩의 변경 요약
  case packChanges(festivalID: String)
  /// 발행 팩 버전·지도 버전
  case packVersion(festivalID: String)
  /// 팩 요청과 변경 알림을 주고받는 WebSocket
  case packUpdates

  public var path: String {
    switch self {
    case let .packChanges(festivalID):
      return "\(FestiCoreDomain.festivals.path)/\(festivalID)/pack/changes"
    case let .packVersion(festivalID):
      return "\(FestiCoreDomain.festivals.path)/\(festivalID)/pack/version"
    case .packUpdates:
      return "\(FestiCoreDomain.festivals.path)/updates"
    }
  }
}
