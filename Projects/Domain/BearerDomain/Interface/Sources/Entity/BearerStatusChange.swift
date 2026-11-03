//
//  BearerStatusChange.swift
//  BearerDomain
//
//  Created by FestiCore on 11/3/26.
//

import Foundation

/// 기수 보드에서 누른 상태 변경. 서버 전이 규칙에 맞는 본문으로 바뀐다.
public enum BearerStatusChange: Sendable, Equatable {
  /// 예정 → 활동 중
  case start(zoneID: String, activity: BearerActivity)
  /// 활동 중·쉬는 중의 존 이동
  case move(zoneID: String)
  /// 활동 중의 활동 변경, 쉬는 중에서 다시 시작
  case activity(BearerActivity)
  case rest
  case end
  /// 오늘 종료 후 다시 시작. KST 하루 한 번이다.
  case restart(zoneID: String, activity: BearerActivity)
}

/// 전송할 상태 변경 한 건. 오프라인 대기열에서 같은 멱등키와 누른 시각으로 다시 보낸다.
public struct BearerStatusRequest: Sendable, Equatable, Identifiable {
  public let change: BearerStatusChange
  public let idempotencyKey: String
  public let clientAt: Date

  public var id: String { idempotencyKey }

  public init(change: BearerStatusChange, idempotencyKey: String, clientAt: Date) {
    self.change = change
    self.idempotencyKey = idempotencyKey
    self.clientAt = clientAt
  }
}
