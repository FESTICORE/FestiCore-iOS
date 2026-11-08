//
//  CoreLocation+LocationInterface.swift
//  FestiCoreLocation
//
//  Created by FestiCore on 11/8/26.
//

import CoreLocation
import FestiCoreLocationInterface

extension LocationAuthorization {
  /// CoreLocation 권한 값을 앱 권한 상태로 바꾼다. 앞으로 생길 알 수 없는 값은 위치를 쓰지 않도록 거부로 본다.
  init(_ status: CLAuthorizationStatus) {
    switch status {
    case .notDetermined:
      self = .notDetermined
    case .restricted:
      self = .restricted
    case .denied:
      self = .denied
    case .authorizedAlways, .authorizedWhenInUse:
      self = .authorized
    @unknown default:
      self = .denied
    }
  }
}

extension LocationCoordinate {
  init(_ coordinate: CLLocationCoordinate2D) {
    self.init(
      latitude: coordinate.latitude,
      longitude: coordinate.longitude
    )
  }
}

extension CLLocationCoordinate2D {
  init(_ coordinate: LocationCoordinate) {
    self.init(
      latitude: coordinate.latitude,
      longitude: coordinate.longitude
    )
  }
}
