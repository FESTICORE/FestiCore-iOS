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
  infoPlist: .extendingDefault(with: [
    "CFBundleShortVersionString": .string("$(FESTICORE_VERSION)"),
    "CFBundleVersion": .string("$(FESTICORE_BUILD_NUMBER)"),
    "NSExtension": .dictionary([
      "NSExtensionPointIdentifier": .string("com.apple.widgetkit-extension")
    ])
  ]),
  dependencies: [.ui(.liveActivity)]
)
