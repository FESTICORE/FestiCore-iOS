//
//  Project.swift
//  FestiCore
//
//  Created by FestiCore on 10/22/26.
//

import ProjectDescription
import DependencyPackagePlugin
import DependencyPlugin
import ProjectTemplatePlugin

let project = Project.makeModule(
  name: "Festival",
  dependencies: [
    .core(.utility),
    .domain(.festival, .interface),
    .domain(.festival),
    .service(.pack, .interface),
    .ui(.liveActivity),
    .ui(.designSystem),
    .ui(.sharedUI),
    .SPM.composableArchitecture,
    .SPM.dependencies
  ],
  hasTests: true,
  hasInterface: true,
  interfaceDependencies: [
    .SPM.composableArchitecture
  ],
  hasDemo: true,
  demoDependencies: [
    .domain(.festival),
    .domain(.festival, .interface),
    .ui(.liveActivity),
    .ui(.designSystem),
    .SPM.composableArchitecture
  ]
)
