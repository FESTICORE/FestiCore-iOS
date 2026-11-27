//
//  AnalyticsConfigurationTests.swift
//  FestiCoreAnalyticsTests
//
//  Created by FestiCore on 10/28/26.
//

import Testing
@testable import FestiCoreAnalytics

struct AnalyticsConfigurationTests {
  @Test func collectionRequiresConsentKnownEnvironmentAndNonTestHost() {
    for environment in ["stage", "production"] {
      #expect(FestiCoreAnalyticsConfiguration.collectionAllowed(
        consent: true,
        environment: environment,
        isTesting: false
      ))
      #expect(!FestiCoreAnalyticsConfiguration.collectionAllowed(
        consent: false,
        environment: environment,
        isTesting: false
      ))
      #expect(!FestiCoreAnalyticsConfiguration.collectionAllowed(
        consent: true,
        environment: environment,
        isTesting: true
      ))
    }
    #expect(!FestiCoreAnalyticsConfiguration.collectionAllowed(
      consent: true,
      environment: nil,
      isTesting: false
    ))
    #expect(!FestiCoreAnalyticsConfiguration.collectionAllowed(
      consent: true,
      environment: "unknown",
      isTesting: false
    ))
  }

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
    ]) == .init(
      dsn: "https://key@example.invalid/1",
      environment: "stage"
    ))
    for invalidDSN in ["not-a-url", "http://key@example.invalid/1", "https://example.invalid/1", "https://key@example.invalid/no-project"] {
      #expect(SentryConfiguration.options(infoDictionary: [
        "FestiCoreEnvironment": "stage",
        "FestiCoreSentryDSN": invalidDSN
      ]) == nil)
    }
    #expect(SentryConfiguration.options(infoDictionary: [
      "FestiCoreEnvironment": "production",
      "FestiCoreSentryDSN": "  https://key@example.invalid/1  "
    ]) == .init(
      dsn: "https://key@example.invalid/1",
      environment: "production"
    ))
  }

  @Test func sentryNormalizesDSNForBothEnvironments() {
    for environment in ["stage", "production"] {
      for dsn in [" \nkey@example.invalid/1\n ", "HTTPS://key@example.invalid/1"] {
        let options = SentryConfiguration.options(infoDictionary: [
          "FestiCoreEnvironment": environment,
          "FestiCoreSentryDSN": dsn
        ])
        #expect(options == .init(
          dsn: "https://key@example.invalid/1",
          environment: environment
        ))
      }
    }
  }

  @Test func sentryRejectsMalformedDSN() {
    for dsn in [
      "key@/1", "@example.invalid/1", "https:", "http:", " https: ",
      "key@example.invalid/no-project", "key@example.invalid:443/1",
      "key@example.invalid/1?query=value", "key@example.invalid/1#fragment",
      "key:secret@example.invalid/1",
      "key@example.invalid/-1", "key@example.invalid/+1", "key@example.invalid/%31"
    ] {
      #expect(SentryConfiguration.options(infoDictionary: [
        "FestiCoreEnvironment": "stage",
        "FestiCoreSentryDSN": dsn
      ]) == nil)
    }
  }
}
