//
//  Project.swift
//  Auth
//
//  Created by FestiCore on 10/29/26.
//

import DependencyPackagePlugin
import DependencyPlugin
import ProjectDescription
import ProjectTemplatePlugin

let project = Project.makeModule(
  name: "Auth",
  dependencies: [
    .domain(.auth, .interface),
    .service(
      .analytics,
      .interface
    ),
    .feature(.web),
    .feature(.web, .interface),
    .ui(.designSystem),
    .SPM.composableArchitecture,
    .SPM.dependencies
  ],
  resources: ["Resources/**"],
  hasTests: true,
  hasInterface: true,
  interfaceDependencies: [
    .domain(.auth, .interface),
    .SPM.composableArchitecture
  ]
)
