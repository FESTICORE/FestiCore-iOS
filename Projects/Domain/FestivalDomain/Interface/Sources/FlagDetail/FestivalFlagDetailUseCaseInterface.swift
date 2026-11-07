//
//  FestivalFlagDetailUseCaseInterface.swift
//  FestivalDomainInterface
//
//  Created by FestiCore on 11/7/26.
//

import Dependencies

/// 깃발 상세 화면이 쓰는 조회·신고·잠금화면 대표 깃발 지정 계약.
public protocol FestivalFlagDetailUseCaseInterface: Sendable {
  /// 깃발 프로필·현장 상태·오늘 계획과 팔로우·대표 여부를 조회한다.
  func detail(flagID: String) async throws(FestivalFlagDetailError) -> FestivalFlagDetail
  /// 고른 사유로 깃발을 신고한다.
  func report(
    flagID: String,
    reason: FestivalFlagReportReason
  ) async throws(FestivalFlagReportError)
  /// 잠금화면에 보일 대표 깃발을 바꾼다. nil이면 해제하고, 서버가 저장한 대표 깃발 ID를 돌려준다.
  func setPinnedFlag(_ flagID: String?) async throws(FestivalFlagPinError) -> String?
}

public enum FestivalFlagDetailUseCaseDependency: TestDependencyKey {
  public static var testValue: any FestivalFlagDetailUseCaseInterface { return MockFestivalFlagDetailUseCase() }
  public static var previewValue: any FestivalFlagDetailUseCaseInterface { return testValue }
}

public extension DependencyValues {
  var festivalFlagDetailUseCase: any FestivalFlagDetailUseCaseInterface {
    get { return self[FestivalFlagDetailUseCaseDependency.self] }
    set { self[FestivalFlagDetailUseCaseDependency.self] = newValue }
  }
}
