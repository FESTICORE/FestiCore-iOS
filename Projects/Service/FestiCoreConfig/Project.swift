//
//  Project.swift
//  FestiCoreConfig
//
//  Created by FestiCore on 10/28/26.
//

import DependencyPackagePlugin
import ProjectDescription
import ProjectTemplatePlugin

let project = Project.makeModule(
  name: "FestiCoreConfig",
  product: .framework,
  dependencies: [
    .SPM.firebaseCore
  ]
)
