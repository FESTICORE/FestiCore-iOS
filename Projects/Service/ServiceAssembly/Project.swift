//
//  Project.swift
//  ServiceAssembly
//
//  Created by FestiCore on 10/22/26.
//

import ProjectDescription
import ProjectTemplatePlugin
import DependencyPlugin
import DependencyPackagePlugin

let project = Project.makeModule(
  name: "ServiceAssembly",
  product: .framework,
  dependencies: [
    .core(.network, .interface),
    .core(.storage),
    .service(.auth),
    .SPM.dependencies
  ],
  hasTests: true
)
