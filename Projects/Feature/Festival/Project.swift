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
    .core(
      .location,
      .interface
    ),
    .core(.utility),
    .domain(.festival, .interface),
    .domain(.userNotification, .interface),
    .service(.pack, .interface),
    .feature(.web),
    .feature(
      .web,
      .interface
    ),
    .ui(.designSystem),
    .ui(.sharedUI),
    .SPM.composableArchitecture,
    .SPM.dependencies
  ],
  hasTests: true,
  testDependencies: [
    .domain(.festival)
  ],
  hasInterface: true,
  interfaceDependencies: [
    .SPM.composableArchitecture
  ],
  hasDemo: true,
  demoDependencies: [
    .core(.location),
    .domain(.festival),
    .domain(.festival, .interface),
    .domain(.userNotification),
    .ui(.liveActivity),
    .ui(.designSystem),
    .SPM.composableArchitecture
  ]
)
