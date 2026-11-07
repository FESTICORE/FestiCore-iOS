//
//  FestivalFlagActionBodyMapper.swift
//  FestivalDomain
//
//  Created by FestiCore on 11/8/26.
//

import APIEndpoint
import FestivalDomainInterface

/// 깃발 상세의 신고·대표 깃발 도메인 값을 요청 본문으로 바꾼다.
enum FestivalFlagActionBodyMapper {
  static func reportBody(_ reason: FestivalFlagReportReason) -> FlagReportBody {
    return FlagReportBody(reason: reason.rawValue)
  }

  static func pinnedFlagBody(_ flagID: String?) -> PinnedFlagBody {
    return PinnedFlagBody(flagId: flagID)
  }
}
