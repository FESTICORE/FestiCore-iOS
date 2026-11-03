//
//  MockFestivalCatalogUseCase.swift
//  FestivalDomainInterface
//
//  Created by FestiCore on 11/2/26.
//

import Dependencies

/// 테스트에서 필요한 동작만 넘긴다. 넘기지 않은 호출은 테스트 이슈로 기록한다.
public struct MockFestivalCatalogUseCase: FestivalCatalogUseCaseInterface {
  private let cachedFestivalsHandler: @Sendable () async throws -> [FestivalCatalogItem]
  private let refreshFestivalsHandler: @Sendable () async throws -> [FestivalCatalogItem]
  private let savedFestivalIDHandler: @Sendable () -> String?
  private let saveSelectedFestivalIDHandler: @Sendable (String?) -> Void

  public init(
    cachedFestivals: @escaping @Sendable () async throws -> [FestivalCatalogItem] = {
      reportIssue("festivalCatalogUseCase.cachedFestivals 미등록")
      throw FestivalUseCaseNotRegistered()
    },
    refreshFestivals: @escaping @Sendable () async throws -> [FestivalCatalogItem] = {
      reportIssue("festivalCatalogUseCase.refreshFestivals 미등록")
      throw FestivalUseCaseNotRegistered()
    },
    savedFestivalID: @escaping @Sendable () -> String? = {
      reportIssue("festivalCatalogUseCase.savedFestivalID 미등록")
      return nil
    },
    saveSelectedFestivalID: @escaping @Sendable (String?) -> Void = { _ in
      reportIssue("festivalCatalogUseCase.saveSelectedFestivalID 미등록")
    }
  ) {
    self.cachedFestivalsHandler = cachedFestivals
    self.refreshFestivalsHandler = refreshFestivals
    self.savedFestivalIDHandler = savedFestivalID
    self.saveSelectedFestivalIDHandler = saveSelectedFestivalID
  }

  public func cachedFestivals() async throws -> [FestivalCatalogItem] {
    try await cachedFestivalsHandler()
  }

  public func refreshFestivals() async throws -> [FestivalCatalogItem] {
    try await refreshFestivalsHandler()
  }

  public func savedFestivalID() -> String? {
    savedFestivalIDHandler()
  }

  public func saveSelectedFestivalID(_ festivalID: String?) {
    saveSelectedFestivalIDHandler(festivalID)
  }
}
