//
//  AnalyticsLiveDependencies.swift
//  FestiCoreAnalytics
//
//  Created by FestiCore on 11/2/26.
//

import Dependencies
import FestiCoreAnalyticsInterface

extension AnalyticsUseCaseDependency: DependencyKey {
  public static var liveValue: any AnalyticsUseCaseInterface { AnalyticsUseCaseImpl() }
}
