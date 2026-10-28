//
//  Project.swift
//  FestiCore
//
//  Created by FestiCore on 10/22/26.
//

import ProjectDescription
import DependencyPackagePlugin
import ProjectTemplatePlugin

let project = Project.makeModule(
  name: "Home",
  dependencies: [.SPM.composableArchitecture],
  hasTests: false
)
