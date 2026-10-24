//
//  Project.swift
//  FestiCoreLiveActivityWidget
//
//  Created by FestiCore on 10/24/26.
//

import DependencyPlugin
import ProjectDescription
import ProjectTemplatePlugin

let project = Project(
  name: "FestiCoreLiveActivityWidget",
  settings: .moduleSettings,
  targets: [
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
      dependencies: [.ui(.liveActivity)],
      settings: .settings(base: [
        "APPLICATION_EXTENSION_API_ONLY": "YES",
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
