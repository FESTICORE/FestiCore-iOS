//
//  MockFestivalZoneMapUseCase.swift
//  FestivalDomainInterface
//
//  Created by FestiCore on 11/8/26.
//

import Dependencies
import Foundation

/// 테스트에서 필요한 동작만 넘긴다. 넘기지 않은 호출은 테스트 이슈로 기록한다.
public struct MockFestivalZoneMapUseCase: FestivalZoneMapUseCaseInterface {
  public var cachedMapHandler: @Sendable (
    String,
    Date
  ) async throws -> FestivalZoneMap?
  public var isMapChangedHandler: @Sendable (FestivalZoneMap) async throws -> Bool

  public init(
    cachedMap: @escaping @Sendable (
      String,
      Date
    ) async throws -> FestivalZoneMap? = { _, _ in
      reportIssue("festivalZoneMapUseCase.cachedMap 미등록")
      throw FestivalPackError.notRegistered
    },
    isMapChanged: @escaping @Sendable (FestivalZoneMap) async throws -> Bool = { _ in
      reportIssue("festivalZoneMapUseCase.isMapChanged 미등록")
      throw FestivalPackError.notRegistered
    }
  ) {
    cachedMapHandler = cachedMap
    isMapChangedHandler = isMapChanged
  }

  public func cachedMap(
    festivalID: String,
    now: Date
  ) async throws -> FestivalZoneMap? {
    return try await cachedMapHandler(
      festivalID,
      now
    )
  }

  public func isMapChanged(_ map: FestivalZoneMap) async throws -> Bool {
    return try await isMapChangedHandler(map)
  }
}
