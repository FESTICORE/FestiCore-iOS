//
//  AppDelegate+Configuration.swift
//  FestiCore
//
//  Created by FestiCore on 10/22/26.
//

import Foundation
import FestiCoreDesignKit
import Mixpanel

extension AppDelegate {
  func configure() {
    configureFonts()
    configureMixpanel()
  }

  func configureFonts() {
    PretendardFontFamily.registerFonts()
  }

  func configureMixpanel() {
    guard let token = AppConfiguration(infoDictionary: Bundle.main.infoDictionary ?? [:])?.mixpanelToken else {
      return
    }

    Mixpanel.initialize(token: token, trackAutomaticEvents: false)
  }
}
