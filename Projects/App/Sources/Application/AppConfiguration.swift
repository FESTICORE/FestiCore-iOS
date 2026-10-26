//
//  AppConfiguration.swift
//  FestiCore
//
//  Created by FestiCore on 10/22/26.
//

import Foundation
import FestiCoreDeviceInterface

enum AppEnvironment: String {
  case stage
  case production
}

struct AppConfiguration {
  let environment: AppEnvironment
  let apnsEnvironment: DeviceRegistrationMetadata.APNsEnvironment?
  let apiBaseURL: URL
  let mixpanelToken: String?
  let sentryDSN: String?

  init?(infoDictionary: [String: Any]) {
    guard
      let rawEnvironment = infoDictionary["FestiCoreEnvironment"] as? String,
      let environment = AppEnvironment(rawValue: rawEnvironment),
      let host = infoDictionary["FestiCoreAPIHost"] as? String,
      !host.isEmpty,
      !host.contains("/"),
      let url = URL(string: "https://\(host)")
    else {
      return nil
    }

    self.environment = environment
    switch infoDictionary["FestiCoreAPNsEnvironment"] as? String {
    case "development": self.apnsEnvironment = .sandbox
    case "production": self.apnsEnvironment = .production
    default: self.apnsEnvironment = nil
    }
    self.apiBaseURL = url
    let token = (infoDictionary["FestiCoreMixpanelToken"] as? String)?
      .trimmingCharacters(in: .whitespacesAndNewlines)
    self.mixpanelToken = token.flatMap { $0.isEmpty ? nil : $0 }
    let dsn = (infoDictionary["FestiCoreSentryDSN"] as? String)?
      .trimmingCharacters(in: .whitespacesAndNewlines)
    self.sentryDSN = dsn.flatMap { $0.isEmpty ? nil : $0 }
  }
}
