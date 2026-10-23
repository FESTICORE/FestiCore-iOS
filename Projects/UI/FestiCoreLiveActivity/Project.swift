//
//  Project.swift
//  FestiCoreLiveActivity
//
//  Created by FestiCore on 10/23/26.
//

import ProjectDescription
import ProjectTemplatePlugin

let project = Project(
  name: "FestiCoreLiveActivity",
  settings: .moduleSettings,
  targets: [
    .target(
      name: "FestiCoreLiveActivity",
      destinations: Project.Environment.deploymentDestination,
      product: .staticFramework,
      bundleId: .appBundleID(name: "FestiCoreLiveActivity"),
      deploymentTargets: Project.Environment.deploymentTarget,
      infoPlist: .moduleInfoPlist,
      buildableFolders: ["Sources"]
    ),
    .target(
      name: "FestiCoreLiveActivityExtension",
      destinations: Project.Environment.deploymentDestination,
      product: .appExtension,
      bundleId: "\(Project.Environment.mainBundleId).LiveActivity",
      deploymentTargets: Project.Environment.deploymentTarget,
      infoPlist: .extendingDefault(with: [
        "CFBundleShortVersionString": .string("$(FESTICORE_VERSION)"),
        "CFBundleVersion": .string("$(FESTICORE_BUILD_NUMBER)"),
        "NSExtension": .dictionary([
          "NSExtensionPointIdentifier": .string("com.apple.widgetkit-extension")
        ])
      ]),
      buildableFolders: ["Extension"],
      dependencies: [.target(name: "FestiCoreLiveActivity")],
      settings: .settings(base: [
        "CODE_SIGN_STYLE": "Manual",
        "DEVELOPMENT_TEAM": .string(Project.Environment.organizationTeamId)
      ], configurations: [
        .debug(
          name: BuildEnvironment.stage.configurationName,
          settings: ["PROVISIONING_PROFILE_SPECIFIER": "match Development \(Project.Environment.mainBundleId).LiveActivity"],
          xcconfig: BuildEnvironment.stage.xcconfigPath
        ),
        .release(
          name: BuildEnvironment.prod.configurationName,
          settings: ["PROVISIONING_PROFILE_SPECIFIER": "match AppStore \(Project.Environment.mainBundleId).LiveActivity"],
          xcconfig: BuildEnvironment.prod.xcconfigPath
        )
      ])
    )
  ]
)
