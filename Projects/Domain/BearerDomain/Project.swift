//
//  Project.swift
//  BearerDomain
//
//  Created by FestiCore on 11/3/26.
//

import DependencyPackagePlugin
import DependencyPlugin
import ProjectDescription
import ProjectTemplatePlugin

let project = Project.makeModule(
  name: "BearerDomain",
  product: .framework,
  dependencies: [
    .core(.network, .interface),
    .service(.auth, .interface),
    .service(.device, .interface),
    .service(.pack, .interface),
    .service(.apiEndpoint),
    .SPM.dependencies
  ],
  hasTests: true,
  hasInterface: true,
  interfaceDependencies: [
    .SPM.dependencies,
    .external(name: "IssueReporting")
  ]
)
