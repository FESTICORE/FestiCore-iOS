//
//  FestivalLiveBoardUseCaseImpl.swift
//  FestivalDomain
//
//  Created by FestiCore on 11/2/26.
//

import Dependencies
import FestivalDomainInterface

/// 라이브 보드 서비스의 최신 축제 상태를 제공한다.
public struct FestivalLiveBoardUseCaseImpl: FestivalLiveBoardUseCaseInterface {
  @Dependency(\.festivalLiveBoardService) private var liveBoardService

  public init() {}

  /// 선택한 축제의 최신 라이브 보드를 조회한다.
  public func liveBoard(for festivalID: String) async throws -> FestivalLiveBoardSnapshot {
    try await liveBoardService.refresh(for: festivalID)
  }
}
