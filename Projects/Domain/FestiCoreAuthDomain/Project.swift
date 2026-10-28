//
//  Project.swift
//  FestiCoreAuthDomain
//
//  Created by FestiCore on 10/29/26.
//

import DependencyPackagePlugin
import DependencyPlugin
import ProjectDescription
import ProjectTemplatePlugin

let project = Project.makeModule(
  name: "FestiCoreAuthDomain",
  product: .framework,
  dependencies: [
    .core(.network, .interface),
    .service(.auth, .interface),
    .SPM.alamofire,
    .SPM.dependencies
  ],
  hasTests: true,
  hasInterface: true,
  interfaceDependencies: [.SPM.dependencies]
)
