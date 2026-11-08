//
//  FestivalLiveActivityDeduplication.swift
//  Festival
//
//  Created by FestiCore on 11/8/26.
//

import FestivalDomainInterface
import Foundation

/// 축제마다 Live Activity를 하나만 남긴다.
/// 앱의 시작 요청과 서버 push-to-start가 겹치면 같은 축제 활동이 둘 생길 수 있다.
enum FestivalLiveActivityDeduplication {
  struct Result: Equatable {
    /// 축제 ID별로 남길 활동.
    let kept: [String: FestivalLiveActivityRecord]
    /// 잠금화면에서 내릴 여분 활동.
    let duplicates: [FestivalLiveActivityRecord]
  }

  /// 앱 토큰 동기화(`LiveActivityTokenSync`)와 같은 순서(시작일, ID)로 첫 활동을 남겨 서버 갱신 대상과 맞춘다.
  static func resolve(_ activities: [FestivalLiveActivityRecord]) -> Result {
    let ordered = activities.sorted {
      if $0.startDate != $1.startDate { return $0.startDate < $1.startDate }
      return $0.id < $1.id
    }
    var kept: [String: FestivalLiveActivityRecord] = [:]
    var duplicates: [FestivalLiveActivityRecord] = []
    for activity in ordered {
      if kept[activity.festivalID] == nil {
        kept[activity.festivalID] = activity
      } else {
        duplicates.append(activity)
      }
    }
    return Result(
      kept: kept,
      duplicates: duplicates
    )
  }
}
