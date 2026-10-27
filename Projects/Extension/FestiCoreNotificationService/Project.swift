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
  infoPlist: .notificationServiceInfoPlist
)
