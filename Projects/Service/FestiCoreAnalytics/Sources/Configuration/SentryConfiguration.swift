//
//  SentryConfiguration.swift
//  FestiCoreAnalytics
//
//  Created by FestiCore on 10/28/26.
//

import Foundation
import FestiCoreLogger
import Sentry

enum SentryConfiguration {
  struct Options: Equatable {
    let dsn: String
    let environment: String
  }

  static func options(infoDictionary: [String: Any]) -> Options? {
    guard let dsn = (infoDictionary["FestiCoreSentryDSN"] as? String)?
      .trimmingCharacters(in: .whitespacesAndNewlines), !dsn.isEmpty,
      let components = URLComponents(string: dsn),
      components.scheme == "https", components.host != nil,
      components.user != nil,
      Int(components.path.dropFirst()) != nil,
      let environment = infoDictionary["FestiCoreEnvironment"] as? String,
      environment == "stage" || environment == "production" else {
      return nil
    }
    return Options(dsn: dsn, environment: environment)
  }

  static func configure(infoDictionary: [String: Any]) {
    guard let configuration = options(infoDictionary: infoDictionary) else {
      let dsn = (infoDictionary["FestiCoreSentryDSN"] as? String)?
        .trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
      if !dsn.isEmpty {
        FestiCoreLogger.error("Sentry 시작 건너뜀: FestiCoreEnvironment 설정이 유효하지 않음", category: .app)
      }
      return
    }
    SentrySDK.start { options in
      options.dsn = configuration.dsn
      options.environment = configuration.environment
      options.sendDefaultPii = false
      options.tracesSampleRate = 0
    }
  }
}
