//
//  Project.swift
//  AuthDomain
//
//  Created by FestiCore on 10/29/26.
//

import DependencyPackagePlugin
import DependencyPlugin
import ProjectDescription
import ProjectTemplatePlugin

let project = Project.makeModule(
  name: "AuthDomain",
  product: .framework,
  dependencies: [
    .core(.network, .interface),
    .service(.auth, .interface),
    .service(.apiEndpoint),
    .SPM.googleSignIn,
    .SPM.dependencies
  ],
  hasTests: true,
  hasInterface: true,
  interfaceDependencies: [
    .SPM.dependencies,
    .external(name: "IssueReporting")
  ]
)
