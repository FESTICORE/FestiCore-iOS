//
//  Project.swift
//  FestiCoreDevice
//
//  Created by FestiCore on 10/24/26.
//

import ProjectDescription
import ProjectTemplatePlugin
import DependencyPlugin
import DependencyPackagePlugin

let project = Project.makeModule(
  name: "FestiCoreDevice",
  product: .framework,
  dependencies: [
    .core(.network, .interface),
    .SPM.alamofire
  ],
  hasTests: true,
  hasInterface: true,
  interfaceDependencies: [.core(.network, .interface), .SPM.dependencies]
)
