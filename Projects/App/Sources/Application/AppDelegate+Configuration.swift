//
//  AppDelegate+Configuration.swift
//  FestiCore
//
//  Created by FestiCore on 10/22/26.
//

import FestiCoreDesignKit

extension AppDelegate {
  func configure() {
    configureFonts()
  }

  func configureFonts() {
    PretendardFontFamily.registerFonts()
  }
}
