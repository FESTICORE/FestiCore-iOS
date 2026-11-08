//
//  Project.swift
//  Bearer
//
//  Created by FestiCore on 11/3/26.
//

import DependencyPackagePlugin
import DependencyPlugin
import ProjectDescription
import ProjectTemplatePlugin

let project = Project.makeModule(
  name: "Bearer",
  dependencies: [
    .domain(.bearer, .interface),
    .core(.utility),
    .ui(.designSystem),
    .ui(.sharedUI),
    .SPM.composableArchitecture,
    .SPM.dependencies
  ],
  hasTests: true,
  hasInterface: true,
  interfaceDependencies: [
    .domain(.bearer, .interface),
    .SPM.composableArchitecture
  ]
)
