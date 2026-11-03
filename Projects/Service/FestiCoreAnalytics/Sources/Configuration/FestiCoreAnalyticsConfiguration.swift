//
//  FestiCoreAnalyticsConfiguration.swift
//  FestiCoreAnalytics
//
//  Created by FestiCore on 10/28/26.
//

import Foundation

import FestiCoreLogger
import Sentry

/// 외부 분석 SDK를 앱 시작 시 한 번 초기화한다. Sentry를 Mixpanel보다 먼저 시작한다.
public enum FestiCoreAnalyticsConfiguration {
  public static func configure() {
    let infoDictionary = Bundle.main.infoDictionary ?? [:]
    SentryConfiguration.configure(infoDictionary: infoDictionary)
    // Sentry가 시작됐을 때만 앱 로그를 Sentry Logs로 보낸다.
    if SentrySDK.isEnabled {
      FestiCoreLogger.addSink(SentryLogSink())
    }
    MixpanelConfiguration.configure(infoDictionary: infoDictionary)
  }
}
