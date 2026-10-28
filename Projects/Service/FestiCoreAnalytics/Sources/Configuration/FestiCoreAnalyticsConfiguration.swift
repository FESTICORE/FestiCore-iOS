//
//  FestiCoreAnalyticsConfiguration.swift
//  FestiCoreAnalytics
//
//  Created by FestiCore on 10/28/26.
//

import Foundation

/// 외부 분석 SDK를 앱 시작 시 한 번 초기화한다. Sentry를 Mixpanel보다 먼저 시작한다.
public enum FestiCoreAnalyticsConfiguration {
  public static func configure() {
    let infoDictionary = Bundle.main.infoDictionary ?? [:]
    SentryConfiguration.configure(infoDictionary: infoDictionary)
    MixpanelConfiguration.configure(infoDictionary: infoDictionary)
  }
}
