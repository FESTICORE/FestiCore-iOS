//
//  AppDelegate+Configuration.swift
//  FestiCore
//
//  Created by FestiCore on 10/22/26.
//

import Foundation
import FestiCoreAnalytics
import FestiCoreAnalyticsInterface
import FestiCoreConfig
import FestiCoreDesignKit

extension AppDelegate {
  func configure() {
    configureFonts()
    FirebaseConfiguration.configure()
    FestiCoreAnalyticsConfiguration.configure()
    analyticsUseCase.registerBaseProperties()
    analyticsUseCase.track(
      .screenView(
        screen: .splash,
        referrer: nil
      )
    )
    configureDeviceRegistration()
  }

  func configureFonts() {
    PretendardFontFamily.registerFonts()
  }
}
