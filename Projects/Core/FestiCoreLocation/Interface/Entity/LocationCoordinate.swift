//
//  LocationCoordinate.swift
//  FestiCoreLocationInterface
//
//  Created by FestiCore on 11/8/26.
//

/// 위도·경도 한 지점. Feature가 CoreLocation 타입을 알지 않도록 이 값만 주고받는다.
public struct LocationCoordinate: Equatable, Hashable, Sendable {
  public let latitude: Double
  public let longitude: Double

  public init(
    latitude: Double,
    longitude: Double
  ) {
    self.latitude = latitude
    self.longitude = longitude
  }

  /// 위도 -90...90, 경도 -180...180 안의 유한한 값인지
  public var isValid: Bool {
    return latitude.isFinite
      && longitude.isFinite
      && (-90...90).contains(latitude)
      && (-180...180).contains(longitude)
  }
}
