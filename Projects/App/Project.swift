//
//  Project.swift
//  FestiCore
//
//  Created by FestiCore on 10/22/26.
//

import DependencyPlugin
import DependencyPackagePlugin
import ProjectTemplatePlugin

import ProjectDescription

let project = Project.makeAppModule(
  name: Project.Environment.appName,
  bundleId: .mainBundleID(),
  settings: .appMainSettings,
  dependencies: [
    .feature(.home),
    .service(.assembly),
    .SPM.dependencies
  ],
  infoPlist: .appInfoPlist,
  entitlements: .file(path: "../../Entitlements/FestiCore.entitlements"),
  hasTests: true
)
