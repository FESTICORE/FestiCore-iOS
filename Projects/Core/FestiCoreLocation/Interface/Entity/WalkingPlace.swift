//
//  WalkingPlace.swift
//  FestiCoreLocationInterface
//
//  Created by FestiCore on 11/8/26.
//

/// 걸어서 갈 목적지(역·셔틀 정류장). 좌표가 없으면 이름으로 기준 위치 근처를 찾는다.
public struct WalkingPlace: Equatable, Sendable {
  /// 지도 앱과 검색에 쓰는 이름
  public let name: String
  /// 서버가 준 목적지 좌표. 있으면 검색하지 않는다.
  public let coordinate: LocationCoordinate?
  /// 이름으로 찾을 때 기준이 되는 위치(축제 장소)
  public let searchCenter: LocationCoordinate?

  public init(
    name: String,
    coordinate: LocationCoordinate? = nil,
    searchCenter: LocationCoordinate? = nil
  ) {
    self.name = name
    self.coordinate = coordinate
    self.searchCenter = searchCenter
  }
}
