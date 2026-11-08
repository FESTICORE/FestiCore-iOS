//
//  BearerRequestBody+Mapper.swift
//  BearerDomain
//
//  Created by FestiCore on 11/3/26.
//

import APIEndpoint
import BearerDomainInterface
import Foundation

extension BearerStatusRequest {
  /// 서버 전이 규칙의 본문. `status`와 `activity`를 함께 보내지 않고, 종료에는 존을 넣지 않는다.
  var body: FlagStatusBody {
    let clientAt = BearerDateFormat.string(from: clientAt)
    switch change {
    case let .start(zoneID, activity):
      return FlagStatusBody(clientAt: clientAt, zoneId: zoneID, activity: activity.rawValue)
    case let .move(zoneID):
      return FlagStatusBody(clientAt: clientAt, zoneId: zoneID)
    case let .activity(activity):
      return FlagStatusBody(clientAt: clientAt, activity: activity.rawValue)
    case .rest:
      return FlagStatusBody(clientAt: clientAt, status: "resting")
    case .end:
      return FlagStatusBody(clientAt: clientAt, status: "ended")
    case let .restart(zoneID, activity):
      return FlagStatusBody(clientAt: clientAt, zoneId: zoneID, activity: activity.rawValue, restart: true)
    }
  }
}

extension BearerProfileChange {
  /// 앞뒤 공백을 지우고, 비운 소개·존은 null로 보낸다.
  var body: FlagProfileBody {
    let trimmedBio = bio?.trimmingCharacters(in: .whitespacesAndNewlines)
    return FlagProfileBody(
      name: name.trimmingCharacters(in: .whitespacesAndNewlines),
      bio: trimmedBio?.isEmpty == false ? trimmedBio : nil,
      tags: tags.map(\.rawValue),
      planVisible: planVisible,
      homeZoneId: homeZoneID,
      plan: plan
    )
  }
}
