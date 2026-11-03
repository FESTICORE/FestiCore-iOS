//
//  BearerOutboxRecordDTO.swift
//  BearerDomain
//
//  Created by FestiCore on 11/3/26.
//

import BearerDomainInterface
import Foundation

/// 파일에 남기는 대기열 한 건. 같은 멱등키와 누른 시각으로 다시 보내려고 그대로 보관한다.
struct BearerOutboxRecordDTO: Codable, Equatable {
  let flagID: String
  let ownerUserID: String?
  let idempotencyKey: String
  let clientAt: Date
  let kind: String
  let zoneID: String?
  let activity: String?

  init(_ item: BearerStatusOutboxImpl.Item) {
    flagID = item.flagID
    ownerUserID = item.ownerUserID
    idempotencyKey = item.request.idempotencyKey
    clientAt = item.request.clientAt
    switch item.request.change {
    case let .start(zoneID, activity):
      (kind, self.zoneID, self.activity) = ("start", zoneID, activity.rawValue)
    case let .move(zoneID):
      (kind, self.zoneID, self.activity) = ("move", zoneID, nil)
    case let .activity(activity):
      (kind, self.zoneID, self.activity) = ("activity", nil, activity.rawValue)
    case .rest:
      (kind, self.zoneID, self.activity) = ("rest", nil, nil)
    case .end:
      (kind, self.zoneID, self.activity) = ("end", nil, nil)
    case let .restart(zoneID, activity):
      (kind, self.zoneID, self.activity) = ("restart", zoneID, activity.rawValue)
    }
  }

  var item: BearerStatusOutboxImpl.Item? {
    let activity = activity.flatMap(BearerActivity.init(rawValue:))
    let change: BearerStatusChange
    switch (kind, zoneID, activity) {
    case let ("start", zone?, activity?): change = .start(zoneID: zone, activity: activity)
    case let ("move", zone?, _): change = .move(zoneID: zone)
    case let ("activity", _, activity?): change = .activity(activity)
    case ("rest", _, _): change = .rest
    case ("end", _, _): change = .end
    case let ("restart", zone?, activity?): change = .restart(zoneID: zone, activity: activity)
    default: return nil
    }
    return .init(
      flagID: flagID,
      ownerUserID: ownerUserID,
      request: BearerStatusRequest(change: change, idempotencyKey: idempotencyKey, clientAt: clientAt)
    )
  }
}
