//
//  FirebaseConfiguration.swift
//  FestiCoreConfig
//
//  Created by FestiCore on 10/28/26.
//

import FirebaseCore

/// 앱에 포함된 GoogleService-Info.plist로 Firebase를 초기화한다.
public enum FirebaseConfiguration {
  public static func configure() {
    guard FirebaseApp.app() == nil else { return }
    FirebaseApp.configure()
  }
}
