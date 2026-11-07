//
//  FestivalFlagDetailUseCaseImpl.swift
//  FestivalDomain
//
//  Created by FestiCore on 11/7/26.
//

import Dependencies
import FestivalDomainInterface

/// 깃발 상세 조회·신고·대표 깃발 지정을 저장소에 맡긴다.
public struct FestivalFlagDetailUseCaseImpl: FestivalFlagDetailUseCaseInterface {
  @Dependency(\.festivalFlagDetailRepository) private var repository

  public init() {}

  public func detail(flagID: String) async throws(FestivalFlagDetailError) -> FestivalFlagDetail {
    return try await repository.detail(flagID: flagID)
  }

  public func report(
    flagID: String,
    reason: FestivalFlagReportReason
  ) async throws(FestivalFlagReportError) {
    try await repository.report(
      flagID: flagID,
      reason: reason
    )
  }

  public func setPinnedFlag(_ flagID: String?) async throws(FestivalFlagPinError) -> String? {
    return try await repository.setPinnedFlag(flagID)
  }
}
