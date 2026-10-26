//
//  Project.swift
//  FestiCoreNotificationService
//
//  Created by FestiCore on 10/26/26.
//

import ProjectDescription
import ProjectTemplatePlugin

let project = Project(
  name: "FestiCoreNotificationService",
  settings: .moduleSettings,
  targets: [
    .target(
      name: "FestiCoreNotificationServiceExtension",
      destinations: Project.Environment.deploymentDestination,
      product: .appExtension,
      bundleId: "\(Project.Environment.mainBundleId).NotificationService",
      deploymentTargets: Project.Environment.deploymentTarget,
      infoPlist: .extendingDefault(with: [
        "CFBundleShortVersionString": .string("$(FESTICORE_VERSION)"),
        "CFBundleVersion": .string("$(FESTICORE_BUILD_NUMBER)"),
        "NSExtension": .dictionary([
          "NSExtensionPointIdentifier": .string("com.apple.usernotifications.service"),
          "NSExtensionPrincipalClass": .string("$(PRODUCT_MODULE_NAME).NotificationService")
        ])
      ]),
      buildableFolders: ["Extension"],
      settings: .settings(base: [
        "APPLICATION_EXTENSION_API_ONLY": "YES",
        "CODE_SIGN_STYLE": "Manual",
        "DEVELOPMENT_TEAM": .string(Project.Environment.organizationTeamId)
      ], configurations: [
        .debug(
          name: BuildEnvironment.stage.configurationName,
          settings: ["PROVISIONING_PROFILE_SPECIFIER": "match Development \(Project.Environment.mainBundleId).NotificationService"],
          xcconfig: BuildEnvironment.stage.xcconfigPath
        ),
        .release(
          name: BuildEnvironment.prod.configurationName,
          settings: ["PROVISIONING_PROFILE_SPECIFIER": "match AppStore \(Project.Environment.mainBundleId).NotificationService"],
          xcconfig: BuildEnvironment.prod.xcconfigPath
        )
      ])
    )
  ]
)
