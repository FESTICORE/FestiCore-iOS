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
    .service(.pack, .interface),
    .ui(.liveActivity),
    .ui(.designSystem),
    .ui(.sharedUI),
    .SPM.kingfisher,
    .SPM.composableArchitecture,
    .SPM.dependencies
  ],
  hasTests: true,
  hasInterface: true,
  interfaceDependencies: [
    .SPM.composableArchitecture
  ]
)
