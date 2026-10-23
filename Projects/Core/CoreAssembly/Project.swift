//
//  Project.swift
//  CoreAssembly
//
//  Created by FestiCore on 10/23/26.
//

import ProjectDescription
import ProjectTemplatePlugin
import DependencyPlugin
import DependencyPackagePlugin

let project = Project.makeModule(
  name: "CoreAssembly",
  dependencies: [
    .core(.logger),
    .core(.network),
    .core(.storage),
    .SPM.dependencies
  ],
  hasTests: true
)
