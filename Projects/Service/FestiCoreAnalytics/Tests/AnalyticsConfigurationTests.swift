//
//  AnalyticsConfigurationTests.swift
//  FestiCoreAnalyticsTests
//
//  Created by FestiCore on 10/28/26.
//

import Testing
@testable import FestiCoreAnalytics

struct AnalyticsConfigurationTests {
  @Test func mixpanelStartsOnlyWithNonblankToken() {
    #expect(MixpanelConfiguration.token(infoDictionary: [:]) == nil)
    #expect(MixpanelConfiguration.token(infoDictionary: ["FestiCoreMixpanelToken": " \n "]) == nil)
    #expect(MixpanelConfiguration.token(infoDictionary: ["FestiCoreMixpanelToken": " token "]) == "token")
  }

  @Test func sentryRequiresDSNAndKnownEnvironment() {
    #expect(SentryConfiguration.options(infoDictionary: ["FestiCoreEnvironment": "stage"]) == nil)
    #expect(SentryConfiguration.options(infoDictionary: [
      "FestiCoreEnvironment": "stage",
      "FestiCoreSentryDSN": " \n "
    ]) == nil)
    #expect(SentryConfiguration.options(infoDictionary: [
      "FestiCoreSentryDSN": "https://key@example.invalid/1"
    ]) == nil)
    #expect(SentryConfiguration.options(infoDictionary: [
      "FestiCoreEnvironment": "other",
      "FestiCoreSentryDSN": "https://key@example.invalid/1"
    ]) == nil)
    #expect(SentryConfiguration.options(infoDictionary: [
      "FestiCoreEnvironment": "stage",
      "FestiCoreSentryDSN": "https://key@example.invalid/1"
    ]) == .init(dsn: "https://key@example.invalid/1", environment: "stage"))
    for invalidDSN in ["not-a-url", "http://key@example.invalid/1", "https://example.invalid/1", "https://key@example.invalid/no-project"] {
      #expect(SentryConfiguration.options(infoDictionary: [
        "FestiCoreEnvironment": "stage",
        "FestiCoreSentryDSN": invalidDSN
      ]) == nil)
    }
    #expect(SentryConfiguration.options(infoDictionary: [
      "FestiCoreEnvironment": "production",
      "FestiCoreSentryDSN": "  https://key@example.invalid/1  "
    ]) == .init(dsn: "https://key@example.invalid/1", environment: "production"))
  }
}
