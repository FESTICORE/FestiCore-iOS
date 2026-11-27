//
//  FirebaseConfigurationTests.swift
//  FestiCoreAnalyticsTests
//
//  Created by FestiCore on 11/28/26.
//

import Testing
@testable import FestiCoreConfig

struct FirebaseConfigurationTests {
  @Test func loggerLevelsNeverEnableVerboseSDKPayloads() {
    #expect(FirebaseConfiguration.loggerLevel(environment: "stage") == .notice)
    #expect(FirebaseConfiguration.loggerLevel(environment: "production") == .error)
    #expect(FirebaseConfiguration.loggerLevel(environment: nil) == .error)
    #expect(FirebaseConfiguration.loggerLevel(environment: "unknown") == .error)
  }
}
