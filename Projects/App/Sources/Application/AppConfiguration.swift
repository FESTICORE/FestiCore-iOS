//
//  AppConfiguration.swift
//  FestiCore
//
//  Created by FestiCore on 10/22/26.
//

import Foundation

enum AppEnvironment: String {
  case stage
  case production
}

struct AppConfiguration {
  let environment: AppEnvironment
  let apiBaseURL: URL

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
    self.apiBaseURL = url
  }
}
