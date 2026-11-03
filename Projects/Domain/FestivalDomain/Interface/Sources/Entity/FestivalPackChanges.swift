//
//  FestivalPackChanges.swift
//  FestivalDomainInterface
//
//  Created by FestiCore on 11/3/26.
//

/// 받은 팩과 현재 발행 팩의 차이
public struct FestivalPackChanges: Equatable, Sendable {
  public let fromVersion: Int
  public let toVersion: Int
  /// 받을 팩 크기(바이트)
  public let sizeBytes: Int
  /// 바뀐 공연 수. 서버에 이전 버전 기록이 없으면 nil이다.
  public let changedSets: Int?
  public let lastShuttleAt: ValueChange?
  public let lastTrainAt: ValueChange?

  public init(
    fromVersion: Int,
    toVersion: Int,
    sizeBytes: Int,
    changedSets: Int?,
    lastShuttleAt: ValueChange? = nil,
    lastTrainAt: ValueChange? = nil
  ) {
    self.fromVersion = fromVersion
    self.toVersion = toVersion
    self.sizeBytes = sizeBytes
    self.changedSets = changedSets
    self.lastShuttleAt = lastShuttleAt
    self.lastTrainAt = lastTrainAt
  }

  public struct ValueChange: Equatable, Sendable {
    public let before: String?
    public let after: String?

    public init(before: String?, after: String?) {
      self.before = before
      self.after = after
    }
  }
}
