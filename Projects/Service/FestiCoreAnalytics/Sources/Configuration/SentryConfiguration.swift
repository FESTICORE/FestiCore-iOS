//
//  SentryConfiguration.swift
//  FestiCoreAnalytics
//
//  Created by FestiCore on 10/28/26.
//

import Foundation
import Sentry

enum SentryConfiguration {
  struct Options: Equatable {
    let dsn: String
    let environment: String
  }

  static func options(infoDictionary: [String: Any]) -> Options? {
    guard let dsn = (infoDictionary["FestiCoreSentryDSN"] as? String)?
      .trimmingCharacters(in: .whitespacesAndNewlines), !dsn.isEmpty,
      let environment = infoDictionary["FestiCoreEnvironment"] as? String,
      environment == "stage" || environment == "production" else {
      return nil
    }
    return Options(dsn: dsn, environment: environment)
  }

  static func configure(infoDictionary: [String: Any]) {
    guard let configuration = options(infoDictionary: infoDictionary) else { return }
    SentrySDK.start { options in
      options.dsn = configuration.dsn
      options.environment = configuration.environment
      options.sendDefaultPii = false
      options.tracesSampleRate = 0
    }
  }
}
