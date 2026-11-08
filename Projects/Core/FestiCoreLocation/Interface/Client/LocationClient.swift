//
//  LocationClient.swift
//  FestiCoreLocationInterface
//
//  Created by FestiCore on 11/8/26.
//

import Dependencies

/// 위치 권한과 현재 위치를 읽는 경계. CoreLocation은 라이브 구현에만 둔다.
public protocol LocationClient: Sendable {
  /// 지금 권한 상태. 권한 팝업을 띄우지 않는다.
  func authorization() async -> LocationAuthorization
  /// 사용 중 위치 권한을 요청하고 사용자가 고른 결과를 돌려준다. 이미 정해졌으면 묻지 않고 그 상태를 돌려준다.
  func requestWhenInUseAuthorization() async -> LocationAuthorization
  /// 현재 위치 한 번. 권한이 없거나 위치를 잡지 못하면 `LocationClientError`를 던진다.
  func currentLocation() async throws -> LocationCoordinate
}

public enum LocationClientDependency: TestDependencyKey {
  public static var testValue: any LocationClient {
    return MockLocationClient()
  }
  /// 프리뷰에서는 권한 팝업 없이 거부 상태로 두어 서버 값을 보인다.
  public static var previewValue: any LocationClient {
    return MockLocationClient(
      authorization: { .denied },
      requestWhenInUseAuthorization: { .denied }
    )
  }
}

public extension DependencyValues {
  var locationClient: any LocationClient {
    get { self[LocationClientDependency.self] }
    set { self[LocationClientDependency.self] = newValue }
  }
}
