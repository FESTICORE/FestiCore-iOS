//
//  FestivalZoneMapUseCaseInterface.swift
//  FestivalDomainInterface
//
//  Created by FestiCore on 11/8/26.
//

import Dependencies
import Foundation

/// Figma S06 존 지도의 지도 데이터. 받아 둔 팩에서 지도를 읽고, 서버 지도 버전과 비교한다.
public protocol FestivalZoneMapUseCaseInterface: Sendable {
  /// 기기에 받은 팩의 존 지도. 팩이 없으면 nil이다. `now`에 공연 중인 아티스트를 무대 머리글에 넣는다.
  func cachedMap(
    festivalID: String,
    now: Date
  ) async throws -> FestivalZoneMap?
  /// 서버 발행 팩의 지도 버전이 받아 둔 지도와 다르면 참이다(Figma S06 J).
  func isMapChanged(_ map: FestivalZoneMap) async throws -> Bool
}

public enum FestivalZoneMapUseCaseDependency: TestDependencyKey {
  public static var testValue: any FestivalZoneMapUseCaseInterface { return MockFestivalZoneMapUseCase() }
  public static var previewValue: any FestivalZoneMapUseCaseInterface { return testValue }
}

public extension DependencyValues {
  var festivalZoneMapUseCase: any FestivalZoneMapUseCaseInterface {
    get { self[FestivalZoneMapUseCaseDependency.self] }
    set { self[FestivalZoneMapUseCaseDependency.self] = newValue }
  }
}
