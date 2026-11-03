//
//  FestivalCatalogUseCaseInterface.swift
//  FestivalDomainInterface
//
//  Created by FestiCore on 11/2/26.
//

import Dependencies

/// 축제 목록을 읽고 마지막으로 고른 축제를 기억한다.
public protocol FestivalCatalogUseCaseInterface: Sendable {
  /// 기기에 저장된 축제 목록. 네트워크에 연결하지 않는다.
  func cachedFestivals() async throws -> [FestivalCatalogItem]
  /// 서버에서 축제 목록을 다시 받는다.
  func refreshFestivals() async throws -> [FestivalCatalogItem]
  /// 마지막으로 고른 축제 ID.
  func savedFestivalID() -> String?
  func saveSelectedFestivalID(_ festivalID: String?)
}

public enum FestivalCatalogUseCaseDependency: TestDependencyKey {
  public static var testValue: any FestivalCatalogUseCaseInterface { MockFestivalCatalogUseCase() }
  public static var previewValue: any FestivalCatalogUseCaseInterface { testValue }
}

public extension DependencyValues {
  var festivalCatalogUseCase: any FestivalCatalogUseCaseInterface {
    get { self[FestivalCatalogUseCaseDependency.self] }
    set { self[FestivalCatalogUseCaseDependency.self] = newValue }
  }
}
