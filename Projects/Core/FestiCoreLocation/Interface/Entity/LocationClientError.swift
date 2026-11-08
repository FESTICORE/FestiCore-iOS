//
//  LocationClientError.swift
//  FestiCoreLocationInterface
//
//  Created by FestiCore on 11/8/26.
//

/// 위치·지도 계산 실패. 호출자는 서버가 준 값으로 대신 보인다.
public enum LocationClientError: Error, Equatable, Sendable {
  /// 사용 중 위치 권한이 없다.
  case notAuthorized
  /// 현재 위치를 잡지 못했다.
  case locationUnavailable
  /// 목적지 이름을 기준 위치 근처에서 찾지 못했다.
  case placeNotFound
  /// 도보 경로를 계산하지 못했다.
  case routeUnavailable
  /// 테스트에서 대역을 넘기지 않았다.
  case notRegistered
}
