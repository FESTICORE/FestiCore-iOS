//
//  MockFestivalFlagDetailUseCase.swift
//  FestivalDomainInterface
//
//  Created by FestiCore on 11/7/26.
//

import Dependencies

/// 테스트·프리뷰용 깃발 상세 유스케이스. 처리기를 주지 않은 호출은 테스트 오류로 알린다.
public struct MockFestivalFlagDetailUseCase: FestivalFlagDetailUseCaseInterface {
  private let detailHandler: @Sendable (String) async throws(FestivalFlagDetailError) -> FestivalFlagDetail

  public init(
    detail: @escaping @Sendable (String) async throws(FestivalFlagDetailError) -> FestivalFlagDetail = { _ in
      reportIssue("festivalFlagDetailUseCase.detail 미등록")
      throw .unavailable
    }
  ) {
    self.detailHandler = detail
  }

  public func detail(flagID: String) async throws(FestivalFlagDetailError) -> FestivalFlagDetail {
    return try await detailHandler(flagID)
  }
}
