//
//  Project.swift
//  FestiCoreNotificationService
//
//  Created by FestiCore on 10/26/26.
//

import ProjectDescription
import ProjectTemplatePlugin

let project = Project.makeAppExtensionModule(
  name: "FestiCoreNotificationService",
  targetName: "FestiCoreNotificationServiceExtension",
  bundleId: "\(Project.Environment.mainBundleId).NotificationService",
  infoPlist: .extendingDefault(with: [
    "CFBundleShortVersionString": .string("$(FESTICORE_VERSION)"),
    "CFBundleVersion": .string("$(FESTICORE_BUILD_NUMBER)"),
    "NSExtension": .dictionary([
      "NSExtensionPointIdentifier": .string("com.apple.usernotifications.service"),
      "NSExtensionPrincipalClass": .string("$(PRODUCT_MODULE_NAME).NotificationService")
    ])
  ])
)
