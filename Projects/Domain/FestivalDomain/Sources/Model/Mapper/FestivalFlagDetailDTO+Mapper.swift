//
//  FestivalFlagDetailDTO+Mapper.swift
//  FestivalDomain
//
//  Created by FestiCore on 11/7/26.
//

import FestivalDomainInterface
import Foundation

extension FestivalFlagDetailDataDTO {
  /// 상태는 정해진 값만 받는다. 모르는 활동은 표시만 생략하도록 nil로 바꾼다.
  func toDomain(imageURL: (String?) -> URL?) throws(FestivalFlagDetailError) -> FestivalFlagDetail {
    guard !id.isEmpty,
          !name.isEmpty,
          let lifecycle = FestivalFlagDetail.Status(rawValue: status.status),
          let updatedAt = Self.parseDate(status.updatedAt) else {
      throw .invalidResponse
    }
    return FestivalFlagDetail(
      id: id,
      name: name,
      thumbnailURL: imageURL(thumbUrl),
      photoURL: imageURL(photoUrl),
      tags: tags,
      bio: bio,
      followerCount: max(
        followerCount,
        0
      ),
      isPlanVisible: planVisible,
      planSetIDs: planVisible ? plan : [],
      homeZoneID: homeZoneId,
      status: lifecycle,
      zoneID: status.zoneId,
      activity: status.activity.flatMap(FestivalFlagDetail.Activity.init(rawValue:)),
      statusUpdatedAt: updatedAt,
      isFollowing: isFollowing,
      isBearer: isBearer,
      isHidden: hidden
    )
  }

  private static func parseDate(_ value: String) -> Date? {
    let fractional = ISO8601DateFormatter()
    fractional.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
    if let date = fractional.date(from: value) { return date }
    return ISO8601DateFormatter().date(from: value)
  }
}
