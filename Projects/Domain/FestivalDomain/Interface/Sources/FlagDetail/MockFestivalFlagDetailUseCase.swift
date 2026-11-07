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
  private let reportHandler: @Sendable (
    String,
    FestivalFlagReportReason
  ) async throws(FestivalFlagReportError) -> Void
  private let setPinnedFlagHandler: @Sendable (String?) async throws(FestivalFlagPinError) -> String?

  public init(
    detail: @escaping @Sendable (String) async throws(FestivalFlagDetailError) -> FestivalFlagDetail = { _ in
      reportIssue("festivalFlagDetailUseCase.detail 미등록")
      throw .unavailable
    },
    report: @escaping @Sendable (
      String,
      FestivalFlagReportReason
    ) async throws(FestivalFlagReportError) -> Void = {
      _, _ throws(FestivalFlagReportError) in
      reportIssue("festivalFlagDetailUseCase.report 미등록")
      throw .unavailable
    },
    setPinnedFlag: @escaping @Sendable (String?) async throws(FestivalFlagPinError) -> String? = {
      _ throws(FestivalFlagPinError) in
      reportIssue("festivalFlagDetailUseCase.setPinnedFlag 미등록")
      throw .unavailable
    }
  ) {
    self.detailHandler = detail
    self.reportHandler = report
    self.setPinnedFlagHandler = setPinnedFlag
  }

  public func detail(flagID: String) async throws(FestivalFlagDetailError) -> FestivalFlagDetail {
    return try await detailHandler(flagID)
  }

  public func report(
    flagID: String,
    reason: FestivalFlagReportReason
  ) async throws(FestivalFlagReportError) {
    try await reportHandler(
      flagID,
      reason
    )
  }

  public func setPinnedFlag(_ flagID: String?) async throws(FestivalFlagPinError) -> String? {
    return try await setPinnedFlagHandler(flagID)
  }
}
