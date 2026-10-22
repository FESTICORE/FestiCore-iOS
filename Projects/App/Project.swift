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
  settings: .moduleSettings,
  dependencies: [
    .feature(.home),
    .service(.assembly)
  ],
  infoPlist: .appInfoPlist,
  hasTests: true
)
