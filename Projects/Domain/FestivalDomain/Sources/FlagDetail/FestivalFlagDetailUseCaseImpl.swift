//
//  FestivalFlagDetailUseCaseImpl.swift
//  FestivalDomain
//
//  Created by FestiCore on 11/7/26.
//

import Dependencies
import FestivalDomainInterface

/// 깃발 상세 조회를 저장소에 맡긴다.
public struct FestivalFlagDetailUseCaseImpl: FestivalFlagDetailUseCaseInterface {
  @Dependency(\.festivalFlagDetailRepository) private var repository

  public init() {}

  public func detail(flagID: String) async throws(FestivalFlagDetailError) -> FestivalFlagDetail {
    return try await repository.detail(flagID: flagID)
  }
}
