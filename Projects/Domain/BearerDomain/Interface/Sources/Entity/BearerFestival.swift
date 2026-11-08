//
//  BearerFestival.swift
//  BearerDomain
//
//  Created by FestiCore on 11/3/26.
//

import Foundation

/// 기기에 받아 둔 축제 팩에서 읽은 이름과 존·공연 목록
public struct BearerFestival: Sendable, Equatable {
  public let id: String
  public let name: String?
  public let zones: [BearerZone]
  /// 오늘 계획으로 고를 수 있는 공연(시작 순)
  public let sets: [BearerSet]

  public init(
    id: String,
    name: String?,
    zones: [BearerZone],
    sets: [BearerSet] = []
  ) {
    self.id = id
    self.name = name
    self.zones = zones
    self.sets = sets
  }

  public func zoneName(for zoneID: String?) -> String? {
    guard let zoneID else { return nil }
    return zones.first { $0.id == zoneID }?.name
  }
}

public struct BearerZone: Sendable, Equatable, Identifiable {
  public let id: String
  public let name: String

  public init(id: String, name: String) {
    self.id = id
    self.name = name
  }
}

/// 팩의 공연 하나. 오늘 계획은 이 ID 목록으로 저장한다.
public struct BearerSet: Sendable, Equatable, Identifiable {
  public let id: String
  public let artist: String
  public let stageName: String?
  public let startsAt: Date
  public let endsAt: Date

  public init(
    id: String,
    artist: String,
    stageName: String?,
    startsAt: Date,
    endsAt: Date
  ) {
    self.id = id
    self.artist = artist
    self.stageName = stageName
    self.startsAt = startsAt
    self.endsAt = endsAt
  }
}
