//
//  Project+Settings.swift
//  FestiCore
//
//  Created by FestiCore on 10/22/26.
//

import ProjectDescription

public extension Settings {
  static var moduleSettings: Settings {
    .settings(configurations: [
      .debug(name: BuildEnvironment.stage.configurationName, xcconfig: BuildEnvironment.stage.xcconfigPath),
      .release(name: BuildEnvironment.prod.configurationName, xcconfig: BuildEnvironment.prod.xcconfigPath)
    ])
  }
}
