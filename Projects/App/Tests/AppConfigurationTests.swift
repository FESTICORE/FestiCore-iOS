//
//  AppConfigurationTests.swift
//  FestiCore
//
//  Created by FestiCore on 10/22/26.
//

import Foundation
import Testing
@testable import FestiCore

struct AppConfigurationTests {
  @Test func stageConfigurationUsesItsOwnHost() throws {
    let configuration = try #require(AppConfiguration(infoDictionary: [
      "FestiCoreEnvironment": "stage",
      "FestiCoreAPIHost": "stage.example.invalid"
    ]))

    #expect(configuration.environment == .stage)
    #expect(configuration.apiBaseURL.absoluteString == "https://stage.example.invalid")
  }

  @Test func missingOrMalformedHostCannotProduceAConfiguration() {
    #expect(AppConfiguration(infoDictionary: ["FestiCoreEnvironment": "production"]) == nil)
    #expect(AppConfiguration(infoDictionary: [
      "FestiCoreEnvironment": "production",
      "FestiCoreAPIHost": "example.invalid/path"
    ]) == nil)
  }
}
