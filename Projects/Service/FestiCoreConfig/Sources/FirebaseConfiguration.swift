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
  public static func configure() {
    guard Bundle.main.url(forResource: "GoogleService-Info", withExtension: "plist") != nil else {
      Logger(subsystem: "io.festiCore.co", category: "configuration")
        .error("Firebase configuration is unavailable in this build")
      return
    }
    FirebaseApp.configure()
  }
}
