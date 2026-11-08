//
//  AppleMapsClient.swift
//  FestiCoreLocationInterface
//
//  Created by FestiCore on 11/8/26.
//

import Dependencies

/// Apple 지도(MapKit)로 목적지를 찾고 도보 시간을 계산하거나 지도 앱을 여는 경계. MapKit은 라이브 구현에만 둔다.
public protocol AppleMapsClient: Sendable {
  /// 출발 지점에서 목적지까지 걸어서 걸리는 시간.
  /// 목적지 좌표가 없으면 이름으로 기준 위치 근처를 찾는다. 찾거나 계산하지 못하면 `LocationClientError`를 던진다.
  func walkingDuration(
    from origin: LocationCoordinate,
    to place: WalkingPlace
  ) async throws -> WalkingDuration
  /// Apple 지도 앱에서 목적지까지 도보 길찾기를 연다. 목적지를 찾지 못했거나 열지 못하면 false다.
  func openWalkingDirections(to place: WalkingPlace) async -> Bool
}

public enum AppleMapsClientDependency: TestDependencyKey {
  public static var testValue: any AppleMapsClient {
    return MockAppleMapsClient()
  }
  /// 프리뷰에서는 지도 계산을 하지 않아 서버 값을 보인다.
  public static var previewValue: any AppleMapsClient {
    return MockAppleMapsClient(
      walkingDuration: { _, _ in
        throw LocationClientError.routeUnavailable
      },
      openWalkingDirections: { _ in false }
    )
  }
}

public extension DependencyValues {
  var appleMapsClient: any AppleMapsClient {
    get { self[AppleMapsClientDependency.self] }
    set { self[AppleMapsClientDependency.self] = newValue }
  }
}
