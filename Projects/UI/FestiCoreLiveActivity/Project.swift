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
      buildableFolders: ["Sources"],
      settings: .settings(base: ["APPLICATION_EXTENSION_API_ONLY": "YES"])
    )
  ]
)
