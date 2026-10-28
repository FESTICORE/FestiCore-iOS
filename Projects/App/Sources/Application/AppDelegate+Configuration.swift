//
//  AppDelegate+Configuration.swift
//  FestiCore
//
//  Created by FestiCore on 10/22/26.
//

import Foundation
import FestiCoreAnalytics
import FestiCoreDesignKit

extension AppDelegate {
  func configure() {
    configureFonts()
    FestiCoreAnalyticsConfiguration.configure()
  }

  func configureFonts() {
    PretendardFontFamily.registerFonts()
  }
}
