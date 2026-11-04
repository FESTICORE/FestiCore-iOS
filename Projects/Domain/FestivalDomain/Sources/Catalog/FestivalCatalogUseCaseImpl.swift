//
//  FestivalCatalogUseCaseImpl.swift
//  FestivalDomain
//
//  Created by FestiCore on 11/2/26.
//

import Dependencies
import FestivalDomainInterface

/// 축제 목록 저장소와 마지막 선택 기록을 조합한다.
public struct FestivalCatalogUseCaseImpl: FestivalCatalogUseCaseInterface {
  @Dependency(\.festivalCatalogRepository) private var catalogRepository
  @Dependency(\.festivalSelectionStore) private var selectionStore

  public init() {}

  /// 저장된 축제 목록을 네트워크 요청 없이 읽는다.
  public func cachedFestivals() async throws -> [FestivalCatalogItem] {
    try await catalogRepository.cachedFestivals()
  }

  /// 서버 목록을 새로 받고 로컬 캐시를 갱신한다.
  public func refreshFestivals() async throws -> [FestivalCatalogItem] {
    try await catalogRepository.refreshFestivals()
  }

  public func festivalDetail(for festivalID: String) async throws -> FestivalPackDocument {
    return try await catalogRepository.festivalDetail(for: festivalID)
  }

  public func festivalPage(
    after: String?,
    limit: Int
  ) async throws -> FestivalCatalogPage {
    return try await catalogRepository.festivalPage(
      after: after,
      limit: limit
    )
  }

  /// 마지막 선택 축제 ID를 기기에서 읽는다.
  public func savedFestivalID() -> String? {
    selectionStore.load()
  }

  /// 마지막 선택 축제 ID를 저장하거나 지운다.
  public func saveSelectedFestivalID(_ festivalID: String?) {
    selectionStore.save(festivalID)
  }
}
