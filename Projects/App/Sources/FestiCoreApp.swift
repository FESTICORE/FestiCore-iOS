//
//  FestiCoreApp.swift
//  FestiCore
//
//  Created by FestiCore on 10/22/26.
//

import SwiftUI
import Home
import ServiceAssembly
import Dependencies

@main
struct FestiCoreApp: App {
  private let configuration = AppConfiguration(infoDictionary: Bundle.main.infoDictionary ?? [:])

  init() {
    prepareDependencies {
      ServiceDependencyAssembly.register(into: &$0)
    }
  }

  var body: some Scene {
    WindowGroup {
      FestiCoreHomeView(configurationIsAvailable: configuration != nil)
    }
  }
}
