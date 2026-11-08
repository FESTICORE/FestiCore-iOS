//
//  CoreLocationClient.swift
//  FestiCoreLocation
//
//  Created by FestiCore on 11/8/26.
//

import CoreLocation
import FestiCoreLocationInterface

/// CoreLocation으로 사용 중 위치 권한과 현재 위치를 읽는다.
struct CoreLocationClient: LocationClient {
  func authorization() async -> LocationAuthorization {
    return await LocationManagerBridge.shared.authorization()
  }

  func requestWhenInUseAuthorization() async -> LocationAuthorization {
    return await LocationManagerBridge.shared.requestWhenInUseAuthorization()
  }

  func currentLocation() async throws -> LocationCoordinate {
    return try await LocationManagerBridge.shared.currentLocation()
  }
}

/// `CLLocationManager`의 위임 콜백을 async 호출로 바꾼다. 관리자와 대기열은 메인 액터에서만 다룬다.
@MainActor
final class LocationManagerBridge: NSObject {
  static let shared = LocationManagerBridge()

  private let manager = CLLocationManager()
  private var authorizationWaiters: [CheckedContinuation<LocationAuthorization, Never>] = []
  private var locationWaiters: [CheckedContinuation<LocationCoordinate, any Error>] = []

  override private init() {
    super.init()
    manager.delegate = self
    // 도보 시간 계산에는 100m 정확도로 충분하고, 더 빨리 위치를 잡는다.
    manager.desiredAccuracy = kCLLocationAccuracyHundredMeters
  }

  func authorization() -> LocationAuthorization {
    return LocationAuthorization(manager.authorizationStatus)
  }

  func requestWhenInUseAuthorization() async -> LocationAuthorization {
    let current = authorization()
    // 권한 문구가 없는 앱(데모 등)은 시스템이 팝업 없이 무시해 응답이 오지 않으므로 묻지 않는다.
    guard current == .notDetermined,
          Bundle.main.object(forInfoDictionaryKey: "NSLocationWhenInUseUsageDescription") != nil else { return current }
    return await withCheckedContinuation { continuation in
      authorizationWaiters.append(continuation)
      // 동시에 여러 번 불려도 시스템 권한 팝업은 한 번만 띄운다.
      guard authorizationWaiters.count == 1 else { return }
      manager.requestWhenInUseAuthorization()
    }
  }

  func currentLocation() async throws -> LocationCoordinate {
    guard authorization() == .authorized else { throw LocationClientError.notAuthorized }
    return try await withCheckedThrowingContinuation { continuation in
      locationWaiters.append(continuation)
      guard locationWaiters.count == 1 else { return }
      manager.requestLocation()
    }
  }

  fileprivate func authorizationChanged(_ authorization: LocationAuthorization) {
    // 위임자를 연결할 때도 현재 상태가 한 번 오므로 아직 정하지 않은 상태는 넘긴다.
    guard authorization != .notDetermined, !authorizationWaiters.isEmpty else { return }
    let waiters = authorizationWaiters
    authorizationWaiters.removeAll()
    waiters.forEach { $0.resume(returning: authorization) }
  }

  fileprivate func locationReceived(_ location: LocationCoordinate?) {
    let waiters = locationWaiters
    locationWaiters.removeAll()
    for waiter in waiters {
      if let location {
        waiter.resume(returning: location)
      } else {
        waiter.resume(throwing: LocationClientError.locationUnavailable)
      }
    }
  }
}

extension LocationManagerBridge: CLLocationManagerDelegate {
  nonisolated func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
    let authorization = LocationAuthorization(manager.authorizationStatus)
    Task { @MainActor in
      self.authorizationChanged(authorization)
    }
  }

  nonisolated func locationManager(
    _ manager: CLLocationManager,
    didUpdateLocations locations: [CLLocation]
  ) {
    // 빈 목록이 와도 기다리는 호출이 끝나도록 위치 없음으로 알린다.
    let location = locations.last.map { LocationCoordinate($0.coordinate) }
    Task { @MainActor in
      self.locationReceived(location)
    }
  }

  nonisolated func locationManager(
    _ manager: CLLocationManager,
    didFailWithError error: any Error
  ) {
    Task { @MainActor in
      self.locationReceived(nil)
    }
  }
}
