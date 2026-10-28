//
//  AppDelegate+Configuration.swift
//  FestiCore
//
//  Created by FestiCore on 10/22/26.
//

import Foundation
import FestiCoreDesignKit
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

    SentrySDK.start { options in
      options.dsn = dsn
      options.environment = (Bundle.main.object(forInfoDictionaryKey: "FestiCoreEnvironment") as? String) ?? "stage"
      options.sendDefaultPii = false
      options.tracesSampleRate = 0
    }
  }
}
