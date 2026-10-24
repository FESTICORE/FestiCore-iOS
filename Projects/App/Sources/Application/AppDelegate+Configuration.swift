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
    guard let token = AppConfiguration(infoDictionary: Bundle.main.infoDictionary ?? [:])?.mixpanelToken else {
      return
    }

    Mixpanel.initialize(token: token, trackAutomaticEvents: false)
  }

  func configureSentry() {
    guard let configuration = AppConfiguration(infoDictionary: Bundle.main.infoDictionary ?? [:]),
          let dsn = configuration.sentryDSN else {
      return
    }

    SentrySDK.start { options in
      options.dsn = dsn
      options.environment = configuration.environment.rawValue
      options.sendDefaultPii = false
      options.tracesSampleRate = 0
    }
  }
}
