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
  @Dependency(\.festivalPackLocalStore) private var localStore
  @Dependency(\.festivalWiFiStatus) private var wiFiStatus

  public init() {}

  public func receivedPacks() async throws -> [FestivalReceivedPack] {
    let packs = try await packService.cachedPacks()
    // 저장된 축제 목록이 없거나 깨져도 받은 팩은 보여 준다.
    let catalog = (try? await catalogService.cachedFestivals()) ?? []
    return packs.receivedPacks(catalog: catalog, imageURL: catalogService.imageURL(for:))
  }

  public func refreshReceivedPacks() async throws -> [FestivalReceivedPack] {
    var packs = try await packService.cachedPacks()
    let catalog = try await catalogService.refresh()
    let received = packs.receivedPacks(catalog: catalog, imageURL: catalogService.imageURL(for:))
    let outdated = received.filter(\.hasUpdate)
    // 와이파이에서 자동으로 받기가 켜져 있으면 새 버전을 바로 받는다. 실패한 팩은 표시하고 다음 확인 때 다시 받는다.
    guard !outdated.isEmpty, localStore.autoDownloadOnWiFi(), await wiFiStatus.isOnWiFi() else {
      return received
    }
    for pack in outdated {
      try Task.checkCancellation()
      // 목록을 읽은 뒤 사용자가 지운 팩은 다시 받지 않는다.
      guard (try? await packService.cachedPack(for: pack.id)) != nil else { continue }
      do {
        _ = try await packService.sync(for: pack.id)
      } catch is CancellationError {
        throw CancellationError()
      } catch {
        // 받지 못한 팩은 아래에서 새 버전이 남아 있는지로 실패를 표시한다.
      }
    }
    try Task.checkCancellation()
    packs = try await packService.cachedPacks()
    let attemptedIDs = Set(outdated.map(\.id))
    return packs.receivedPacks(catalog: catalog, imageURL: catalogService.imageURL(for:)).map { pack in
      var pack = pack
      pack.autoUpdateFailed = attemptedIDs.contains(pack.id) && pack.hasUpdate
      return pack
    }
  }
}
