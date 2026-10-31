//
//  Project.swift
//  FestiCore
//
//  Created by FestiCore on 10/30/26.
//

import ProjectDescription
import DependencyPackagePlugin
import DependencyPlugin
import ProjectTemplatePlugin

let project = Project.makeModule(
  name: "Timetable",
  dependencies: [
    .domain(.festival, .interface),
    .ui(.designSystem),
    .ui(.sharedUI),
    .SPM.composableArchitecture
  ],
  hasTests: true,
  hasInterface: true,
  interfaceDependencies: [
    .SPM.composableArchitecture
  ],
  hasDemo: true,
  demoDependencies: [
    .ui(.designSystem),
    .SPM.composableArchitecture
  ]
)
