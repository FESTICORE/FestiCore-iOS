//
//  AnalyticsUseCaseInterface.swift
//  FestiCoreAnalyticsInterface
//
//  Created by FestiCore on 11/2/26.
//

import Dependencies

/// 사용자 이벤트를 Mixpanel과 Sentry에 남기는 계약.
public protocol AnalyticsUseCaseInterface: Sendable {
  func track(_ event: AnalyticsEvent)
}

public enum AnalyticsUseCaseDependency: TestDependencyKey {
  public static var testValue: any AnalyticsUseCaseInterface { MockAnalyticsUseCase() }
  public static var previewValue: any AnalyticsUseCaseInterface { MockAnalyticsUseCase(reportsUnregisteredCall: false) }
}

public extension DependencyValues {
  var analyticsUseCase: any AnalyticsUseCaseInterface {
    get { self[AnalyticsUseCaseDependency.self] }
    set { self[AnalyticsUseCaseDependency.self] = newValue }
  }
}
