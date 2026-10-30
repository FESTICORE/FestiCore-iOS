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
    .ui(.designSystem),
    .SPM.composableArchitecture
  ],
  hasTests: true
)
