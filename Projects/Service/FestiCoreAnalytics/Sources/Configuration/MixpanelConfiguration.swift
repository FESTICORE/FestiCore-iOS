//
//  MixpanelConfiguration.swift
//  FestiCoreAnalytics
//
//  Created by FestiCore on 10/28/26.
//

import Foundation
import Mixpanel

enum MixpanelConfiguration {
  static func token(infoDictionary: [String: Any]) -> String? {
    guard let token = (infoDictionary["FestiCoreMixpanelToken"] as? String)?
      .trimmingCharacters(in: .whitespacesAndNewlines), !token.isEmpty else { return nil }
    return token
  }

  static func configure(infoDictionary: [String: Any]) {
    guard let token = token(infoDictionary: infoDictionary) else { return }
    let instance = Mixpanel.initialize(
      token: token,
      trackAutomaticEvents: false
    )
    instance.useIPAddressForGeoLocation = false
    // SDK 자체 상세 로그는 token·payload를 포함할 수 있어 환경과 무관하게 끈다.
    instance.loggingEnabled = false
  }
}
