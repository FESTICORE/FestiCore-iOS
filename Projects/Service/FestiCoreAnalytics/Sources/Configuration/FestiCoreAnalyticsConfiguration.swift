//
//  FestiCoreAnalyticsConfiguration.swift
//  FestiCoreAnalytics
//
//  Created by FestiCore on 10/28/26.
//

import Foundation

import ComposableArchitecture
import FestiCoreLogger
import FestiCoreStorageInterface
import FirebaseAnalytics
import FirebaseCore
import Mixpanel
import SentrySwift

/// 기존 분석 계층에서 동의와 환경에 따라 SDK 수집을 함께 제어한다.
public enum FestiCoreAnalyticsConfiguration {
  static var isCollectionEnabled: Bool {
    @SharedReader(.analyticsCollectionEnabled) var enabled
    return collectionAllowed(
      consent: enabled,
      environment: Bundle.main.infoDictionary?["FestiCoreEnvironment"] as? String,
      isTesting: ProcessInfo.processInfo.environment["XCTestConfigurationFilePath"] != nil
    )
  }

  static func collectionAllowed(
    consent: Bool,
    environment: String?,
    isTesting: Bool
  ) -> Bool {
    return consent && !isTesting && (environment == "stage" || environment == "production")
  }

  public static func configure() {
    let isProduction = Bundle.main.infoDictionary?["FestiCoreEnvironment"] as? String == "production"
    FestiCoreLogger.addSink(SentryLogSink(minimumLevel: isProduction ? .error : .info))
    applyCollectionPreference()
  }

  static func applyCollectionPreference() {
    let enabled = isCollectionEnabled
    if FirebaseApp.app() != nil {
      Analytics.setConsent([
        .analyticsStorage: enabled ? .granted : .denied,
        .adStorage: .denied,
        .adUserData: .denied,
        .adPersonalization: .denied
      ])
      Analytics.setAnalyticsCollectionEnabled(enabled)
      if !enabled {
        Analytics.setUserID(nil)
        Analytics.resetAnalyticsData()
      }
    }
    if enabled {
      if Mixpanel.safeMainInstance() == nil {
        MixpanelConfiguration.configure(infoDictionary: Bundle.main.infoDictionary ?? [:])
      } else if let instance = Mixpanel.safeMainInstance(), instance.hasOptedOutTracking() {
        instance.optInTracking()
      }
      if !SentrySDK.isEnabled {
        SentryConfiguration.configure(infoDictionary: Bundle.main.infoDictionary ?? [:])
      }
    } else {
      Mixpanel.safeMainInstance()?.optOutTracking()
      SentrySDK.setUser(nil)
      SentrySDK.close()
    }
  }
}
