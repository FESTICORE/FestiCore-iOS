//
//  FestivalWiFiStatusClient.swift
//  FestivalDomainInterface
//
//  Created by FestiCore on 11/3/26.
//

import Dependencies

/// 지금 와이파이로 연결돼 있는지 알려 준다. 팩 자동 받기에 쓴다.
public struct FestivalWiFiStatusClient: Sendable {
  public var isOnWiFi: @Sendable () async -> Bool

  public init(isOnWiFi: @escaping @Sendable () async -> Bool) {
    self.isOnWiFi = isOnWiFi
  }
}

extension FestivalWiFiStatusClient: TestDependencyKey {
  public static let testValue = Self(isOnWiFi: { false })
}

public extension DependencyValues {
  var festivalWiFiStatus: FestivalWiFiStatusClient {
    get { self[FestivalWiFiStatusClient.self] }
    set { self[FestivalWiFiStatusClient.self] = newValue }
  }
}
