//
//  FestiCoreDesignKitDemoApp.swift
//  FestiCoreDesignKitDemo
//
//  Created by FestiCore on 10/23/26.
//

import FestiCoreDesignKit
import SwiftUI

@main
struct FestiCoreDesignKitDemoApp: App {
  init() {
    PretendardFontFamily.registerFonts()
  }

  var body: some Scene {
    WindowGroup {
      FestiCoreDesignKitCatalogView()
    }
  }
}
