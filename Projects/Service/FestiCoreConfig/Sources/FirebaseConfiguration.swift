//
//  FirebaseConfiguration.swift
//  FestiCoreConfig
//
//  Created by FestiCore on 10/28/26.
//

import FirebaseCore
import Foundation
import OSLog

/// 앱에 포함된 GoogleService-Info.plist로 Firebase를 초기화한다.
public enum FirebaseConfiguration {
  /// Stage는 SDK 진단 notice까지, Prod/알 수 없는 환경은 error만 기록한다.
  static func loggerLevel(environment: String?) -> FirebaseLoggerLevel {
    return environment == "stage" ? .notice : .error
  }

  public static func configure() {
    guard ProcessInfo.processInfo.environment["XCTestConfigurationFilePath"] == nil else { return }
    FirebaseCore.FirebaseConfiguration.shared.setLoggerLevel(loggerLevel(
      environment: Bundle.main.infoDictionary?["FestiCoreEnvironment"] as? String
    ))

    guard Bundle.main.url(
      forResource: "GoogleService-Info",
      withExtension: "plist"
    ) != nil else {
      Logger(
        subsystem: "io.festiCore.co",
        category: "configuration"
      )
        .error("Firebase configuration is unavailable in this build")
      return
    }
    if FirebaseApp.app() == nil { FirebaseApp.configure() }
  }
}
