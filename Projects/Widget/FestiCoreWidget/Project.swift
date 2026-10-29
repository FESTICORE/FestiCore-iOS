//
//  Project.swift
//  FestiCoreWidget
//
//  Created by FestiCore on 10/24/26.
//

import DependencyPlugin
import ProjectDescription
import ProjectTemplatePlugin

let project = Project.makeAppExtensionModule(
  name: "FestiCoreWidget",
  targetName: "FestiCoreLiveActivityExtension",
  bundleId: "\(Project.Environment.mainBundleId).LiveActivity",
  infoPlist: .liveActivityWidgetInfoPlist,
  dependencies: [.ui(.liveActivity)]
)
