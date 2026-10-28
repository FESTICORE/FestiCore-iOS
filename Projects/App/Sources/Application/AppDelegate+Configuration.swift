//
//  AppDelegate+Configuration.swift
//  FestiCore
//
//  Created by FestiCore on 10/22/26.
//

import FestiCoreAnalytics
import FestiCoreDesignKit

extension AppDelegate {
  func configure() {
    FestiCoreAnalyticsConfiguration.configure()
    configureFonts()
  }

  func configureFonts() {
    PretendardFontFamily.registerFonts()
  }
}
