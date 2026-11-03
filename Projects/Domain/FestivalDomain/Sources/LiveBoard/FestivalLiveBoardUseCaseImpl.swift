//
//  FestivalLiveBoardUseCaseImpl.swift
//  FestivalDomain
//
//  Created by FestiCore on 11/2/26.
//

import Dependencies
import FestivalDomainInterface

public struct FestivalLiveBoardUseCaseImpl: FestivalLiveBoardUseCaseInterface {
  @Dependency(\.festivalLiveBoardService) private var liveBoardService

  public init() {}

  public func liveBoard(for festivalID: String) async throws -> FestivalLiveBoardSnapshot {
    try await liveBoardService.refresh(for: festivalID)
  }
}
