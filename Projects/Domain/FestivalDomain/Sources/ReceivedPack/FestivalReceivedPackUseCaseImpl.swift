//
//  FestivalReceivedPackUseCaseImpl.swift
//  FestivalDomain
//
//  Created by FestiCore on 11/3/26.
//

import Dependencies
import FestiCorePackInterface
import FestivalDomainInterface

public struct FestivalReceivedPackUseCaseImpl: FestivalReceivedPackUseCaseInterface {
  @Dependency(\.packSyncService) private var packService
  @Dependency(\.festivalCatalogService) private var catalogService

  public init() {}

  public func receivedPacks() async throws -> [FestivalReceivedPack] {
    let packs = try await packService.cachedPacks()
    // 저장된 축제 목록이 없거나 깨져도 받은 팩은 보여 준다.
    let catalog = (try? await catalogService.cachedFestivals()) ?? []
    return packs.receivedPacks(catalog: catalog, imageURL: catalogService.imageURL(for:))
  }

  public func refreshReceivedPacks() async throws -> [FestivalReceivedPack] {
    let packs = try await packService.cachedPacks()
    let catalog = try await catalogService.refresh()
    return packs.receivedPacks(catalog: catalog, imageURL: catalogService.imageURL(for:))
  }
}
