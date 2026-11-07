//
//  FestivalFlagDetailContext+Board.swift
//  FestiCore
//
//  Created by FestiCore on 11/8/26.
//

import FeatureAssembly
import FestivalDomainInterface
import FestiCoreUtility
import Foundation

extension FestivalFlagDetailContext {
  /// 선택 축제 보드에서 깃발 상세의 표시 입력을 만든다. 다른 축제의 팩·일정·대표 깃발은 섞지 않는다.
  /// - Parameters:
  ///   - board: 깃발 탭이 따르는 축제 목록·라이브 보드 상태
  ///   - snapshot: 깃발 디렉토리가 받은 라이브 보드(대표 깃발 ID)
  init(
    board: FestivalFeature.State?,
    snapshot: FestivalLiveBoardSnapshot?
  ) {
    let festivalID = board?.selectedFestivalID
    let pack = board?.displayDocument.flatMap { $0.id == festivalID ? $0 : nil }
    let schedule = board?.mySchedule.flatMap { $0.festivalID == festivalID ? $0 : nil }
    let pinnedSnapshot = snapshot.flatMap { $0.festivalID == festivalID ? $0 : nil }
    self.init(
      zoneNames: Self.zoneNames(pack),
      performances: Self.performances(pack),
      mySetIDs: schedule?.setIDs ?? [],
      hasSession: board?.hasSession ?? false,
      accountID: board?.sessionUserID,
      pinnedFlagID: pinnedSnapshot?.pinnedFlagID
    )
  }
}

private extension FestivalFlagDetailContext {
  static func zoneNames(_ pack: FestivalPackDocument?) -> [String: String] {
    let zones = pack?.zones ?? []
    return Dictionary(
      zones.map { ($0.id, $0.name) },
      uniquingKeysWith: { first, _ in first }
    )
  }

  /// 시작·종료 시각을 읽을 수 있는 공연만 계획 행에 쓴다.
  static func performances(_ pack: FestivalPackDocument?) -> [String: Performance] {
    let entries = (pack?.performances ?? []).compactMap { performance -> (String, Performance)? in
      guard let startsAt = performance.startsAt?.isoDate,
            let endsAt = performance.endsAt?.isoDate else { return nil }
      return (
        performance.id,
        Performance(
          artist: performance.artist ?? "출연진 미정",
          stageName: performance.stageName ?? "무대 미정",
          startsAt: startsAt,
          endsAt: endsAt
        )
      )
    }
    return Dictionary(
      entries,
      uniquingKeysWith: { first, _ in first }
    )
  }
}
