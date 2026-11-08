//
//  FestivalHomeDeparture.swift
//  Festival
//
//  Created by FestiCore on 11/8/26.
//

import FestivalDomainInterface
import Foundation

/// 귀가 카드가 안내할 출발편. 지금 걸어가도 탈 수 있는 막차를 먼저, 안 되면 셔틀을 고른다.
struct FestivalHomeDeparture: Equatable {
  enum Kind: Equatable {
    case train
    case shuttle
  }

  let kind: Kind
  let date: Date

  /// 걸어서 닿을 수 있는 편이 없으면 아직 떠나지 않은 첫 편을 그대로 안내한다. 모두 떠났으면 nil이다.
  init?(
    directions: FestivalPackDetail.Directions,
    walkMinutes: FestivalFeature.HomeWalkMinutes,
    now: Date
  ) {
    let upcoming = [
      Candidate(
        kind: .train,
        value: directions.lastTrainAt,
        walkMinutes: walkMinutes.station,
        now: now
      ),
      Candidate(
        kind: .shuttle,
        value: directions.lastShuttleAt,
        walkMinutes: walkMinutes.shuttleStop,
        now: now
      ),
    ].compactMap { $0 }
    guard let chosen = upcoming.first(where: { $0.isReachable(now: now) }) ?? upcoming.first else { return nil }
    kind = chosen.kind
    date = chosen.date
  }

  var name: String {
    switch kind {
    case .train:
      return "막차"
    case .shuttle:
      return "셔틀"
    }
  }

  /// 출발까지 남은 분. 남는 초는 1분으로 올린다.
  func remainingMinutes(now: Date) -> Int {
    return Int(ceil(date.timeIntervalSince(now) / 60))
  }
}

private extension FestivalHomeDeparture {
  /// 아직 떠나지 않은 출발편 하나
  struct Candidate {
    let kind: Kind
    let date: Date
    let walkMinutes: Int?

    init?(
      kind: Kind,
      value: String?,
      walkMinutes: Int?,
      now: Date
    ) {
      guard let value = value?.trimmingCharacters(in: .whitespacesAndNewlines), !value.isEmpty,
            let date = Self.departureDate(
              value,
              now: now
            ),
            date > now else { return nil }
      self.kind = kind
      self.date = date
      self.walkMinutes = walkMinutes
    }

    /// 지금 걸어가도 출발 전에 닿는지. 도보 시간을 모르면 떠나기 전이면 닿는다고 본다.
    func isReachable(now: Date) -> Bool {
      let walkSeconds = TimeInterval((walkMinutes ?? 0) * 60)
      return date.timeIntervalSince(now) > walkSeconds
    }

    /// ISO 시각 또는 `HH:mm`. `HH:mm`이 저녁에 본 새벽 시각이면 다음 날로 본다.
    private static func departureDate(
      _ value: String,
      now: Date
    ) -> Date? {
      if let date = FestivalLiveBoardSchedule.parse(value) { return date }
      let parts = value.split(separator: ":")
      guard parts.count == 2,
            let hour = Int(parts[0]), (0...23).contains(hour),
            let minute = Int(parts[1]), (0...59).contains(minute),
            let seoulTimeZone = TimeZone(identifier: "Asia/Seoul") else { return nil }
      var calendar = Calendar(identifier: .gregorian)
      calendar.timeZone = seoulTimeZone
      guard let sameDay = calendar.date(
        bySettingHour: hour,
        minute: minute,
        second: 0,
        of: now
      ) else { return nil }
      if sameDay <= now, hour < 6, calendar.component(
        .hour,
        from: now
      ) >= 18 {
        return calendar.date(
          byAdding: .day,
          value: 1,
          to: sameDay
        )
      }
      return sameDay
    }
  }
}
