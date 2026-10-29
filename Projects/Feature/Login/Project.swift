//
//  Project.swift
//  Login
//
//  Created by FestiCore on 10/29/26.
//

import DependencyPackagePlugin
import DependencyPlugin
import ProjectDescription
import ProjectTemplatePlugin

let project = Project.makeModule(
  name: "Login",
  dependencies: [
    .domain(.auth, .interface),
    .SPM.composableArchitecture,
    .SPM.dependencies
  ],
  hasTests: true,
  hasInterface: true,
  interfaceDependencies: [.SPM.composableArchitecture]
)
