//
//  Project.swift
//  Profile
//
//  Created by FestiCore on 10/30/26.
//

import DependencyPackagePlugin
import DependencyPlugin
import ProjectDescription
import ProjectTemplatePlugin

let project = Project.makeModule(
  name: "Profile",
  dependencies: [
    .domain(.auth, .interface),
    .ui(.animation),
    .ui(.designSystem),
    .ui(.sharedUI),
    .SPM.composableArchitecture
  ],
  hasTests: true,
  hasInterface: true,
  interfaceDependencies: [
    .SPM.composableArchitecture
  ]
)
