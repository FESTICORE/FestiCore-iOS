//
//  Project.swift
//  FestiCoreLocation
//
//  Created by FestiCore on 11/8/26.
//

import ProjectDescription
import ProjectTemplatePlugin
import DependencyPackagePlugin

let project = Project.makeModule(
  name: "FestiCoreLocation",
  product: .framework,
  dependencies: [
    .SPM.dependencies
  ],
  hasTests: true,
  hasInterface: true,
  interfaceDependencies: [
    .SPM.dependencies
  ]
)
