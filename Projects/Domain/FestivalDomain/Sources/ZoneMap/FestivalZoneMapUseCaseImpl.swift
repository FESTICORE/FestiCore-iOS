//
//  FestivalZoneMapUseCaseImpl.swift
//  FestivalDomain
//
//  Created by FestiCore on 11/8/26.
//

import Dependencies
import FestiCorePackInterface
import FestivalDomainInterface
import Foundation

/// 받아 둔 팩에서 존 지도를 읽고 Repository로 서버 지도 버전과 비교하는 UseCase
public struct FestivalZoneMapUseCaseImpl: FestivalZoneMapUseCaseInterface {
  @Dependency(\.packSyncService) private var packService
  @Dependency(\.festivalZoneMapRepository) private var repository

  public init() {}

  public func cachedMap(
    festivalID: String,
    now: Date
  ) async throws -> FestivalZoneMap? {
    guard let cached = try await packService.cachedPack(for: festivalID) else { return nil }
    let dto = try JSONDecoder().decode(
      FestivalZoneMapPackDTO.self,
      from: cached.pack
    )
    return dto.toDomain(
      festivalID: festivalID,
      now: now
    )
  }

  public func isMapChanged(_ map: FestivalZoneMap) async throws -> Bool {
    let latest = try await repository.latestMapVersion(festivalID: map.festivalID)
    return latest != map.version
  }
}
