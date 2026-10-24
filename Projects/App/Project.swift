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
    .feature(.assembly),
    .ui(.designSystem),
    .ui(.liveActivity),
    .service(.assembly),
    .service(.device, .interface),
    .project(target: "FestiCoreLiveActivityExtension", path: .relativeToUI("FestiCoreLiveActivity")),
    .SPM.composableArchitecture,
    .SPM.tcaFlow,
    .SPM.dependencies,
    .SPM.mixpanel,
    .SPM.sentry
  ],
  sources: ["Sources/**"],
  resources: ["Resources/**"],
  infoPlist: .appInfoPlist,
  entitlements: .file(path: "../../Entitlements/FestiCore.entitlements"),
  hasTests: true
)
