//
//  Project+Settings.swift
//  FestiCore
//
//  Created by FestiCore on 10/22/26.
//

import ProjectDescription

public extension Settings {
  static var appMainSettings: Settings {
    .settings(base: [
      "AS_AUTHENTICATION_SERVICES_ENABLED": "YES",
      "CODE_SIGN_STYLE": "Manual",
      "DEVELOPMENT_TEAM": .string(Project.Environment.organizationTeamId),
      "MARKETING_VERSION": "$(FESTICORE_VERSION)",
      "CURRENT_PROJECT_VERSION": "$(FESTICORE_BUILD_NUMBER)"
    ], configurations: [
      .debug(
        name: BuildEnvironment.stage.configurationName,
        settings: ["PROVISIONING_PROFILE_SPECIFIER": .string("match Development \(Project.Environment.mainBundleId)")],
        xcconfig: BuildEnvironment.stage.xcconfigPath
      ),
      .release(
        name: BuildEnvironment.prod.configurationName,
        settings: ["PROVISIONING_PROFILE_SPECIFIER": .string("match AppStore \(Project.Environment.mainBundleId)")],
        xcconfig: BuildEnvironment.prod.xcconfigPath
      )
    ])
  }

  static var moduleSettings: Settings {
    .settings(base: [
      "OTHER_SWIFT_FLAGS": "$(inherited) -module-alias Sharing=FestiCorePointFreeSharing"
    ], configurations: [
      .debug(name: BuildEnvironment.stage.configurationName, xcconfig: BuildEnvironment.stage.xcconfigPath),
      .release(name: BuildEnvironment.prod.configurationName, xcconfig: BuildEnvironment.prod.xcconfigPath)
    ])
  }
}
