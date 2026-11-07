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
    .domain(.auth, .interface),
    .domain(.festival, .interface),
    .domain(.timetable, .interface),
    .service(.auth, .interface),
    .core(.network, .interface),
    .core(.storage, .interface),
    .ui(.designSystem),
    .ui(.sharedUI),
    .ui(.animation),
    .ui(.liveActivity),
    .core(.logger),
    .core(.utility),
    .core(.assembly),
    .service(.analytics),
    .service(.analytics, .interface),
    .service(.assembly),
    .service(.config),
    .service(.device, .interface),
    .widget(.liveActivity),
    .appExtension(.notificationService),
    .SPM.composableArchitecture,
    .SPM.tcaFlow,
    .SPM.dependencies
  ],
  sources: ["Sources/**"],
  resources: ["Resources/**"],
  infoPlist: .appInfoPlist,
  entitlements: .file(path: "../../Entitlements/FestiCore.entitlements"),
  hasTests: true,
  testDependencies: [
    .domain(.festival),
    .feature(.timetable)
  ],
  hasUITests: true
)
