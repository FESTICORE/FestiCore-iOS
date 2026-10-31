//
//  Project.swift
//  FestiCoreLiveActivity
//
//  Created by FestiCore on 10/23/26.
//

import ProjectDescription
import ProjectTemplatePlugin
import DependencyPlugin
import DependencyPackagePlugin

let project = Project.makeModule(
  name: "FestiCoreLiveActivity",
  dependencies: [
    .domain(.festival, .interface),
    .SPM.dependencies
  ],
  targetSettings: .settings(base: ["APPLICATION_EXTENSION_API_ONLY": "YES"])
)
