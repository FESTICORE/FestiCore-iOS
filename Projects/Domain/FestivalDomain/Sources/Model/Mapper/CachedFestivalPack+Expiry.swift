//
//  CachedFestivalPack+Expiry.swift
//  FestivalDomain
//
//  Created by FestiCore on 11/13/26.
//

import FestiCorePackInterface
import FestiCoreUtility
import FestivalDomainInterface
import Foundation

extension CachedFestivalPack {
  /// 페스티벌 마지막 날 종료 시각. 일자가 없거나 한 날이라도 종료 시각을 읽을 수 없으면 nil이다.
  var festivalEndsAt: Date? {
    guard let dto = try? JSONDecoder().decode(
      FestivalPackScheduleDTO.self,
      from: pack
    ),
      let days = dto.days, !days.isEmpty else { return nil }
    let endDates = days.compactMap { $0.endsAt?.isoDate }
    guard endDates.count == days.count else { return nil }
    return endDates.max()
  }

  /// 마지막 날 종료 후 보관 기간이 끝나는 시각. 종료 시각을 모르면 nil이라 지우지 않는다.
  var expiresAt: Date? {
    return festivalEndsAt.map { endsAt in
      return endsAt.addingTimeInterval(TimeInterval(FestivalPackRetention.days * 24 * 60 * 60))
    }
  }
}
