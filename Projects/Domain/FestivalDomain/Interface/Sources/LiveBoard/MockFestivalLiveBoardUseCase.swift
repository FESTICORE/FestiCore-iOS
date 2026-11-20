//
//  MockFestivalLiveBoardUseCase.swift
//  FestivalDomainInterface
//
//  Created by FestiCore on 11/2/26.
//

import Dependencies
import Foundation

/// 테스트에서 필요한 동작만 넘긴다. 넘기지 않은 호출은 테스트 이슈로 기록한다.
public struct MockFestivalLiveBoardUseCase: FestivalLiveBoardUseCaseInterface {
  private let liveBoardHandler: @Sendable (String) async throws -> FestivalLiveBoardSnapshot
  private let officialNewsHandler: @Sendable (String) async throws -> FestivalOfficialNews

  /// 공식 소식은 라이브 보드를 감시할 때 함께 불리는 보조 정보라, 넘기지 않으면 비어 있는 소식을 돌려준다.
  public init(
    liveBoard: @escaping @Sendable (String) async throws -> FestivalLiveBoardSnapshot = { _ in
      reportIssue("festivalLiveBoardUseCase.liveBoard 미등록")
      throw FestivalUseCaseNotRegistered()
    },
    officialNews: @escaping @Sendable (String) async throws -> FestivalOfficialNews = { _ in
      return .unavailable
    }
  ) {
    self.liveBoardHandler = liveBoard
    self.officialNewsHandler = officialNews
  }

  public func liveBoard(for festivalID: String) async throws -> FestivalLiveBoardSnapshot {
    return try await liveBoardHandler(festivalID)
  }

  public func officialNews(for festivalID: String) async throws -> FestivalOfficialNews {
    return try await officialNewsHandler(festivalID)
  }
}
