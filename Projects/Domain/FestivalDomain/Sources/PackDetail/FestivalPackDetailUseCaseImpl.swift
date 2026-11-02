//
//  FestivalPackDetailUseCaseImpl.swift
//  FestivalDomain
//
//  Created by FestiCore on 11/3/26.
//

import Dependencies
import FestiCorePackInterface
import FestivalDomainInterface
import Foundation

public struct FestivalPackDetailUseCaseImpl: FestivalPackDetailUseCaseInterface {
  @Dependency(\.packSyncService) private var packService
  @Dependency(\.festivalCatalogService) private var catalogService
  @Dependency(\.festivalPackRepository) private var repository
  @Dependency(\.festivalPackLocalStore) private var localStore

  public init() {}

  public func packDetail(festivalID: String) async throws -> FestivalPackDetail? {
    guard let cached = try await packService.cachedPack(for: festivalID) else { return nil }
    let catalog = (try? await catalogService.cachedFestivals()) ?? []
    return detail(from: cached, catalog: catalog)
  }

  public func packChanges(festivalID: String, fromVersion: Int) async throws -> FestivalPackChanges {
    try await repository.packChanges(festivalID: festivalID, fromVersion: fromVersion)
  }

  public func updatePack(festivalID: String) async throws -> FestivalPackDetail? {
    switch try await packService.sync(for: festivalID) {
    case .updated, .notModified:
      break
    case .retryAfter, .reconnecting:
      throw FestivalPackError.retryLater
    }
    // 받은 버전이 최신인지 다시 판단하도록 서버 목록도 새로 받는다.
    let catalog = (try? await catalogService.refresh()) ?? ((try? await catalogService.cachedFestivals()) ?? [])
    guard let cached = try await packService.cachedPack(for: festivalID) else { return nil }
    return detail(from: cached, catalog: catalog)
  }

  public func deletePack(festivalID: String) async throws {
    try await packService.deletePack(for: festivalID)
  }

  public func checklist(festivalID: String) -> FestivalChecklist {
    localStore.loadChecklist(festivalID)
  }

  public func saveChecklist(_ checklist: FestivalChecklist, festivalID: String) {
    localStore.saveChecklist(checklist, festivalID)
  }

  public func autoDownloadOnWiFi() -> Bool {
    localStore.autoDownloadOnWiFi()
  }

  public func setAutoDownloadOnWiFi(_ isOn: Bool) {
    localStore.setAutoDownloadOnWiFi(isOn)
  }

  private func detail(from cached: CachedFestivalPack, catalog: [FestivalCatalogItem]) -> FestivalPackDetail {
    let pack = cached.receivedPack(
      catalogItem: catalog.first { $0.id == cached.festivalID },
      imageURL: catalogService.imageURL(for:)
    )
    guard let dto = try? JSONDecoder().decode(FestivalPackDetailDTO.self, from: cached.pack) else {
      return FestivalPackDetail(pack: pack)
    }
    return dto.toDomain(pack: pack)
  }
}
