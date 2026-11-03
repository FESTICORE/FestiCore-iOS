//
//  Project.swift
//  NoticeDomain
//

import DependencyPackagePlugin
import DependencyPlugin
import ProjectDescription
import ProjectTemplatePlugin

let project = Project.makeModule(
  name: "NoticeDomain",
  product: .framework,
  dependencies: [
    .core(.network, .interface),
    .core(.utility),
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
