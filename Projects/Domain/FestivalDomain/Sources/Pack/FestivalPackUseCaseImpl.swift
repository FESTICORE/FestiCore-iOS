//
//  FestivalPackUseCaseImpl.swift
//  FestivalDomain
//
//  Created by FestiCore on 11/2/26.
//

import Dependencies
import FestiCorePackInterface
import FestivalDomainInterface

public struct FestivalPackUseCaseImpl: FestivalPackUseCaseInterface {
  @Dependency(\.packSyncService) private var packService

  public init() {}

  public func cachedPacks() async throws -> [CachedFestivalPack] {
    try await packService.cachedPacks()
  }

  public func packUpdates(for festivalID: String) -> AsyncThrowingStream<PackSyncResult, Error> {
    packService.updates(for: festivalID)
  }
}
