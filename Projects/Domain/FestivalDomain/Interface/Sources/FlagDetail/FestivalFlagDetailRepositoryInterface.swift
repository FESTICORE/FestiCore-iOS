//
//  FestivalFlagDetailRepositoryInterface.swift
//  FestivalDomainInterface
//
//  Created by FestiCore on 11/7/26.
//

import Dependencies

/// 깃발 상세 화면의 통신을 정의한다. 공개 상세 조회와 로그인 사용자의 신고·잠금화면 대표 깃발 지정을 맡는다.
public protocol FestivalFlagDetailRepositoryInterface: Sendable {
  /// 로그인 상태면 팔로우·기수·대표 여부를 함께 받는다.
  func detail(flagID: String) async throws(FestivalFlagDetailError) -> FestivalFlagDetail
  /// 깃발을 신고한다. 계정마다 한 번만 받는다.
  func report(
    flagID: String,
    reason: FestivalFlagReportReason
  ) async throws(FestivalFlagReportError)
  /// 잠금화면 대표 깃발을 바꾸고 서버가 저장한 대표 깃발 ID를 돌려준다. nil이면 해제한다.
  func setPinnedFlag(_ flagID: String?) async throws(FestivalFlagPinError) -> String?
}

public enum FestivalFlagDetailRepositoryDependency: TestDependencyKey {
  public static var testValue: any FestivalFlagDetailRepositoryInterface {
    return UnregisteredFestivalFlagDetailRepository()
  }
  public static var previewValue: any FestivalFlagDetailRepositoryInterface { return testValue }
}

public extension DependencyValues {
  var festivalFlagDetailRepository: any FestivalFlagDetailRepositoryInterface {
    get { return self[FestivalFlagDetailRepositoryDependency.self] }
    set { self[FestivalFlagDetailRepositoryDependency.self] = newValue }
  }
}

/// 저장소가 주입되지 않은 호출을 테스트 오류로 알린다.
private struct UnregisteredFestivalFlagDetailRepository: FestivalFlagDetailRepositoryInterface {
  func detail(flagID _: String) async throws(FestivalFlagDetailError) -> FestivalFlagDetail {
    reportIssue("festivalFlagDetailRepository.detail 미등록")
    throw .unavailable
  }

  func report(
    flagID _: String,
    reason _: FestivalFlagReportReason
  ) async throws(FestivalFlagReportError) {
    reportIssue("festivalFlagDetailRepository.report 미등록")
    throw .unavailable
  }

  func setPinnedFlag(_: String?) async throws(FestivalFlagPinError) -> String? {
    reportIssue("festivalFlagDetailRepository.setPinnedFlag 미등록")
    throw .unavailable
  }
}
