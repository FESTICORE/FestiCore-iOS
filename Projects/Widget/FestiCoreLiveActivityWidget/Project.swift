//
//  Project.swift
//  FestiCoreLiveActivityWidget
//
//  Created by FestiCore on 10/24/26.
//

import DependencyPlugin
import ProjectDescription
import ProjectTemplatePlugin

let project = Project.makeAppExtensionModule(
  name: "FestiCoreLiveActivityWidget",
  targetName: "FestiCoreLiveActivityExtension",
  bundleId: "\(Project.Environment.mainBundleId).LiveActivity",
  infoPlist: .liveActivityWidgetInfoPlist,
  dependencies: [.ui(.liveActivity)]
)
