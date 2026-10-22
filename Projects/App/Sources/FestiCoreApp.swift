//
//  FestiCoreApp.swift
//  FestiCore
//
//  Created by FestiCore on 10/22/26.
//

import SwiftUI
import Home

@main
struct FestiCoreApp: App {
  private let configuration = AppConfiguration(infoDictionary: Bundle.main.infoDictionary ?? [:])

  var body: some Scene {
    WindowGroup {
      FestiCoreHomeView(configurationIsAvailable: configuration != nil)
    }
  }
}
