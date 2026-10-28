//
//  AppDelegate+Configuration.swift
//  FestiCore
//
//  Created by FestiCore on 10/22/26.
//

import Foundation
import FestiCoreDesignKit
import FestiCoreLogger
import Mixpanel
import Sentry

extension AppDelegate {
  func configure() {
    configureSentry()
    configureFonts()
    configureMixpanel()
  }

  func configureFonts() {
    PretendardFontFamily.registerFonts()
  }

  func configureMixpanel() {
    guard let token = (Bundle.main.object(forInfoDictionaryKey: "FestiCoreMixpanelToken") as? String)?
      .trimmingCharacters(in: .whitespacesAndNewlines), !token.isEmpty else {
      return
    }

    Mixpanel.initialize(token: token, trackAutomaticEvents: false)
  }

  func configureSentry() {
    guard let dsn = (Bundle.main.object(forInfoDictionaryKey: "FestiCoreSentryDSN") as? String)?
      .trimmingCharacters(in: .whitespacesAndNewlines), !dsn.isEmpty else {
      return
    }
    guard let environment = Bundle.main.object(forInfoDictionaryKey: "FestiCoreEnvironment") as? String,
          environment == "stage" || environment == "production" else {
      FestiCoreLogger.error("Sentry 시작 건너뜀: FestiCoreEnvironment 설정이 유효하지 않음", category: .app)
      return
    }

    SentrySDK.start { options in
      options.dsn = dsn
      options.environment = environment
      options.sendDefaultPii = false
      options.tracesSampleRate = 0
    }
  }
}
