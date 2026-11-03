//
//  FestivalCatalogUseCaseImpl.swift
//  FestivalDomain
//
//  Created by FestiCore on 11/2/26.
//

import Dependencies
import FestivalDomainInterface

public struct FestivalCatalogUseCaseImpl: FestivalCatalogUseCaseInterface {
  @Dependency(\.festivalCatalogService) private var catalogService
  @Dependency(\.festivalSelectionStore) private var selectionStore

  public init() {}

  public func cachedFestivals() async throws -> [FestivalCatalogItem] {
    try await catalogService.cachedFestivals()
  }

  public func refreshFestivals() async throws -> [FestivalCatalogItem] {
    try await catalogService.refresh()
  }

  public func savedFestivalID() -> String? {
    selectionStore.load()
  }

  public func saveSelectedFestivalID(_ festivalID: String?) {
    selectionStore.save(festivalID)
  }
}
