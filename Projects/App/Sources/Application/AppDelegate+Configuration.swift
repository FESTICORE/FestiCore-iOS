//
//  AppDelegate+Configuration.swift
//  FestiCore
//
//  Created by FestiCore on 10/22/26.
//

import Foundation
import FestiCoreAnalytics
import FestiCoreConfig
import FestiCoreDesignKit

extension AppDelegate {
  func configure() {
    configureFonts()
    FirebaseConfiguration.configure()
    FestiCoreAnalyticsConfiguration.configure()
  }

  func configureFonts() {
    PretendardFontFamily.registerFonts()
  }
}
