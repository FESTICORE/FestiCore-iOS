//
//  PushRegistrationService.swift
//  FestiCore
//
//  Created by FestiCore on 11/15/26.
//

import Foundation

import ServiceAssembly

enum PushRegistrationService {
  /// Info.plist 값과 토큰으로 기기 등록 메타데이터를 만든다. APNs 환경이나 앱 버전 설정이 잘못되면 nil이다.
  static func metadata(
    infoDictionary: [String: Any],
    apnsToken: String?,
    liveActivityStartToken: String?,
    osVersion: String,
    locale: String,
    timezone: String
  ) -> DeviceRegistrationMetadata? {
    let apnsEnvironment: DeviceRegistrationMetadata.APNsEnvironment
    switch infoDictionary["FestiCoreAPNsEnvironment"] as? String {
    case "development": apnsEnvironment = .sandbox
    case "production": apnsEnvironment = .production
    default: return nil
    }
    guard let appVersion = infoDictionary["CFBundleShortVersionString"] as? String,
          !appVersion.isEmpty else { return nil }

    return DeviceRegistrationMetadata(
      apnsEnvironment: apnsEnvironment,
      apnsToken: apnsToken,
      liveActivityPushToStartToken: liveActivityStartToken,
      appVersion: appVersion,
      osVersion: osVersion,
      locale: locale,
      timezone: timezone
    )
  }
}
