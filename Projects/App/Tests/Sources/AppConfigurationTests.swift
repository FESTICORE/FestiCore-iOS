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
      "FestiCoreAPNsEnvironment": "development",
      "FestiCoreAPIHost": "stage.example.invalid"
    ]))

    #expect(configuration.environment == .stage)
    #expect(configuration.apiBaseURL.absoluteString == "https://stage.example.invalid")
  }

  @Test func missingOrMalformedHostCannotProduceAConfiguration() {
    #expect(AppConfiguration(infoDictionary: ["FestiCoreEnvironment": "production"]) == nil)
    #expect(AppConfiguration(infoDictionary: [
      "FestiCoreEnvironment": "production",
      "FestiCoreAPNsEnvironment": "production",
      "FestiCoreAPIHost": "example.invalid/path"
    ]) == nil)
  }

  @Test func mixpanelTokenIsOptionalAndWhitespaceIsIgnored() throws {
    let requiredValues: [String: Any] = [
      "FestiCoreEnvironment": "stage",
      "FestiCoreAPNsEnvironment": "development",
      "FestiCoreAPIHost": "stage.example.invalid"
    ]

    #expect(try #require(AppConfiguration(infoDictionary: requiredValues)).mixpanelToken == nil)
    #expect(try #require(AppConfiguration(infoDictionary: requiredValues.merging([
      "FestiCoreMixpanelToken": "  \n "
    ]) { _, new in new })).mixpanelToken == nil)
    #expect(try #require(AppConfiguration(infoDictionary: requiredValues.merging([
      "FestiCoreMixpanelToken": "  project-token  "
    ]) { _, new in new })).mixpanelToken == "project-token")
  }

  @Test func sentryDSNIsOptionalAndWhitespaceIsIgnored() throws {
    let requiredValues: [String: Any] = [
      "FestiCoreEnvironment": "production",
      "FestiCoreAPNsEnvironment": "production",
      "FestiCoreAPIHost": "example.invalid"
    ]

    #expect(try #require(AppConfiguration(infoDictionary: requiredValues)).sentryDSN == nil)
    #expect(try #require(AppConfiguration(infoDictionary: requiredValues.merging([
      "FestiCoreSentryDSN": "  \n "
    ]) { _, new in new })).sentryDSN == nil)
    #expect(try #require(AppConfiguration(infoDictionary: requiredValues.merging([
      "FestiCoreSentryDSN": "  https://key@example.invalid/1  "
    ]) { _, new in new })).sentryDSN == "https://key@example.invalid/1")
  }

  @Test func apnsEnvironmentFollowsSigningRatherThanAPIHost() throws {
    let configuration = try #require(AppConfiguration(infoDictionary: [
      "FestiCoreEnvironment": "stage",
      "FestiCoreAPNsEnvironment": "production",
      "FestiCoreAPIHost": "stage.example.invalid"
    ]))
    #expect(configuration.environment == .stage)
    #expect(configuration.apnsEnvironment == .production)
  }
}
