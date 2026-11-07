//
//  FestivalFlagDetailRows.swift
//  Festival
//
//  Created by FestiCore on 11/7/26.
//

import Foundation

/// "지금" 카드에 보일 내용.
enum FestivalFlagDetailNow: Equatable {
  /// 현재 위치와 활동. isMuted면 쉬는 중·오래된 정보·오프라인이라 흐리게 보인다.
  case located(
    zone: String,
    activity: String,
    source: String,
    isMuted: Bool
  )
  /// 오늘 활동이 끝났다.
  case ended
}

/// "오늘 계획" 한 줄.
struct FestivalFlagDetailPlanRow: Equatable, Identifiable {
  enum Timing: Equatable {
    case upcoming
    case now
    case past
  }

  let id: String
  let time: String
  let artist: String
  let stage: String
  let timing: Timing
  let isMine: Bool
}
