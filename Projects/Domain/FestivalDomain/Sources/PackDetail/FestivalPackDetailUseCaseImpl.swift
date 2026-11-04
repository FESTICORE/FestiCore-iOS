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

/// 받은 팩의 상세 정보와 준비물 및 갱신 설정을 관리한다.
public struct FestivalPackDetailUseCaseImpl: FestivalPackDetailUseCaseInterface {
  @Dependency(\.packSyncService) private var packService
  @Dependency(\.festivalCatalogService) private var catalogService
  @Dependency(\.festivalPackRepository) private var repository
  @Dependency(\.festivalPackLocalStore) private var localStore

  public init() {}

  /// 로컬 팩과 저장된 축제 목록을 합쳐 상세 정보를 만든다.
  public func packDetail(festivalID: String) async throws -> FestivalPackDetail? {
    guard let cached = try await packService.cachedPack(for: festivalID) else { return nil }
    let catalog = (try? await catalogService.cachedFestivals()) ?? []
    return detail(from: cached, catalog: catalog)
  }

  /// 받은 버전 이후 서버 팩의 변경 사항을 조회한다.
  public func packChanges(festivalID: String, fromVersion: Int) async throws -> FestivalPackChanges {
    try await repository.packChanges(festivalID: festivalID, fromVersion: fromVersion)
  }

  /// 팩을 동기화한 뒤 목록도 갱신해 최신 상세 정보를 만든다.
  public func updatePack(festivalID: String) async throws -> FestivalPackDetail? {
    let result: PackSyncResult
    do {
      result = try await packService.sync(for: festivalID)
    } catch where PackSyncError.isTransportFailure(error) {
      throw FestivalPackError.offline
    }
    switch result {
    case .updated, .notModified:
      break
    case .retryAfter, .reconnecting:
      throw FestivalPackError.retryLater
    }
    // 받은 버전이 최신인지 다시 판단하도록 서버 목록도 새로 받는다.
    let catalog: [FestivalCatalogItem]
    if let refreshed = try? await catalogService.refresh() {
      catalog = refreshed
    } else {
      catalog = (try? await catalogService.cachedFestivals()) ?? []
    }
    guard let cached = try await packService.cachedPack(for: festivalID) else { return nil }
    return detail(from: cached, catalog: catalog)
  }

  /// 기기 팩 캐시만 삭제하고 준비물 기록은 유지한다.
  public func deletePack(festivalID: String) async throws {
    try await packService.deletePack(for: festivalID)
  }

  /// 축제별 준비물 기록을 읽는다.
  public func checklist(festivalID: String) -> FestivalChecklist {
    localStore.loadChecklist(festivalID)
  }

  /// 축제별 준비물 기록을 저장한다.
  public func saveChecklist(_ checklist: FestivalChecklist, festivalID: String) {
    localStore.saveChecklist(checklist, festivalID)
  }

  /// 와이파이 자동 갱신 설정을 읽는다.
  public func autoDownloadOnWiFi() -> Bool {
    localStore.autoDownloadOnWiFi()
  }

  /// 와이파이 자동 갱신 설정을 저장한다.
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
