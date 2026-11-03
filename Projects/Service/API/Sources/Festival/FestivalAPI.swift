//
//  FestivalAPI.swift
//  API
//
//  Created by FestiCore on 11/3/26.
//

public enum FestivalAPI: Sendable {
  /// 받은 팩과 현재 발행 팩의 변경 요약
  case packChanges(festivalID: String)

  public var path: String {
    switch self {
    case let .packChanges(festivalID):
      return "\(FestiCoreDomain.festivals.path)/\(festivalID)/pack/changes"
    }
  }
}
