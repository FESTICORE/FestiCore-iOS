//
//  Project.swift
//  FestiCoreAuth
//
//  Created by FestiCore on 10/22/26.
//

import ProjectDescription
import ProjectTemplatePlugin
import DependencyPlugin
import DependencyPackagePlugin

let project = Project.makeModule(
  name: "FestiCoreAuth",
  product: .framework,
  dependencies: [
    .core(.logger),
    .core(.network),
    .core(.storage, .interface),
    .service(.apiEndpoint)
  ],
  hasTests: true,
  hasInterface: true,
  interfaceDependencies: [.core(.network, .interface), .SPM.dependencies]
)
