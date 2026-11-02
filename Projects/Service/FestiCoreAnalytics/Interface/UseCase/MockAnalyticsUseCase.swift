//
//  MockAnalyticsUseCase.swift
//  FestiCoreAnalyticsInterface
//
//  Created by FestiCore on 11/2/26.
//

import IssueReporting

/// 테스트·프리뷰 기본값. 테스트에서 주입하지 않은 호출은 이슈로 기록하고 이벤트를 보내지 않는다.
public struct MockAnalyticsUseCase: AnalyticsUseCaseInterface {
  private let reportsUnregisteredCall: Bool

  public init(reportsUnregisteredCall: Bool = true) {
    self.reportsUnregisteredCall = reportsUnregisteredCall
  }

  public func track(_ event: AnalyticsEvent) {
    guard reportsUnregisteredCall else { return }
    reportIssue("analyticsUseCase 미등록")
  }
}
