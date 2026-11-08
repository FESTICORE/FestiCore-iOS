//
//  FestivalZoneMapDTO+.swift
//  FestivalDomain
//
//  Created by FestiCore on 11/8/26.
//

import FestivalDomainInterface
import Foundation

extension FestivalZoneMapPackDTO {
  /// 존은 `order` 순서로, 무대 머리글은 팩의 무대 이름과 `now`의 공연으로 만든다.
  func toDomain(
    festivalID: String,
    now: Date
  ) -> FestivalZoneMap {
    let stageNames = Dictionary(
      stages.map { ($0.id, $0.name) },
      uniquingKeysWith: { first, _ in first }
    )
    let orderedZones = zones.enumerated().sorted { lhs, rhs in
      let left = lhs.element.order ?? Int.max
      let right = rhs.element.order ?? Int.max
      return left == right ? lhs.offset < rhs.offset : left < right
    }
    return FestivalZoneMap(
      festivalID: festivalID,
      version: mapVersion,
      imageURL: mapImageUrl.flatMap(URL.init(string:)),
      aspect: mapAspect.flatMap { $0 > 0 ? $0 : nil },
      flagsEnabled: flagsEnabled ?? true,
      zones: orderedZones.map { $0.element.toDomain() },
      stageHeaders: mapStages.compactMap { header in
        guard let name = stageNames[header.stageId] else { return nil }
        return FestivalZoneMap.StageHeader(
          stageID: header.stageId,
          name: name,
          x: header.x,
          y: header.y,
          width: header.w,
          nowPlaying: nowPlaying(
            stageID: header.stageId,
            now: now
          )
        )
      }
    )
  }

  private func nowPlaying(
    stageID: String,
    now: Date
  ) -> String? {
    return sets.first { set in
      guard set.stageId == stageID,
            let starts = set.startsAt.flatMap(Self.date),
            let ends = set.endsAt.flatMap(Self.date)
      else { return false }
      return starts <= now && now < ends
    }?.artist
  }

  private static func date(_ value: String) -> Date? {
    return try? Date(
      value,
      strategy: .iso8601
    )
  }
}

extension FestivalZoneMapPackDTO.ZoneDTO {
  func toDomain() -> FestivalZoneMap.Zone {
    return FestivalZoneMap.Zone(
      id: id,
      name: name,
      kind: kind,
      area: area.map {
        FestivalZoneMap.Area(
          x: $0.x,
          y: $0.y,
          width: $0.w,
          height: $0.h
        )
      },
      landmark: landmark
    )
  }
}
