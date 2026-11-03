//
//  BearerFestival.swift
//  BearerDomain
//
//  Created by FestiCore on 11/3/26.
//

import Foundation

/// 기기에 받아 둔 축제 팩에서 읽은 이름과 존 목록
public struct BearerFestival: Sendable, Equatable {
  public let id: String
  public let name: String?
  public let zones: [BearerZone]

  public init(id: String, name: String?, zones: [BearerZone]) {
    self.id = id
    self.name = name
    self.zones = zones
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
