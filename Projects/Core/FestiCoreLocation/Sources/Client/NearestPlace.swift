//
//  NearestPlace.swift
//  FestiCoreLocation
//
//  Created by FestiCore on 11/8/26.
//

import CoreLocation
import FestiCoreLocationInterface

/// 이름 검색 후보 중 실제 목적지로 쓸 곳을 고른다. 같은 이름의 먼 역을 고르지 않게 한다.
enum NearestPlace {
  /// 기준 위치에서 `radius` 안의 가장 가까운 후보.
  /// 잘못된 좌표는 버리고, 기준 위치가 잘못됐거나 쓸 후보가 없으면 nil이다.
  static func match(
    _ candidates: [LocationCoordinate],
    near center: LocationCoordinate,
    within radius: CLLocationDistance
  ) -> LocationCoordinate? {
    guard center.isValid else { return nil }
    let valid = candidates.filter(\.isValid)
    let origin = CLLocation(
      latitude: center.latitude,
      longitude: center.longitude
    )
    let nearest = valid
      .map { candidate in
        let distance = origin.distance(from: CLLocation(
          latitude: candidate.latitude,
          longitude: candidate.longitude
        ))
        return (
          coordinate: candidate,
          distance: distance
        )
      }
      .filter { $0.distance <= radius }
      .min { $0.distance < $1.distance }
    return nearest?.coordinate
  }
}
