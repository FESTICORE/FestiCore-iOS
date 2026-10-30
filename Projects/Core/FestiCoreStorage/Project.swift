//
//  Project.swift
//  FestiCoreStorage
//
//  Created by FestiCore on 10/22/26.
//

import ProjectDescription
import ProjectTemplatePlugin
import DependencyPackagePlugin

let project = Project.makeModule(
  name: "FestiCoreStorage",
  product: .framework,
  dependencies: [
    .SPM.sqliteData,
    .SPM.dependencies
  ],
  hasTests: true,
  hasInterface: true,
  interfaceDependencies: [
    .SPM.dependencies,
    .SPM.sharing
  ]
)
