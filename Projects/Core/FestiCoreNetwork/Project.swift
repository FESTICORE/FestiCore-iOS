//
//  Project.swift
//  FestiCoreNetwork
//
//  Created by FestiCore on 10/22/26.
//

import ProjectDescription
import ProjectTemplatePlugin
import DependencyPlugin
import DependencyPackagePlugin

let project = Project.makeModule(
  name: "FestiCoreNetwork",
  product: .framework,
  dependencies: [.core(.logger), .SPM.alamofire],
  hasTests: true,
  hasInterface: true,
  interfaceDependencies: [.SPM.alamofire, .SPM.dependencies]
)
