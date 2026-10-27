//
//  Project.swift
//  FestiCoreSharedUI
//
//  Created by FestiCore on 10/22/26.
//

import ProjectDescription
import ProjectTemplatePlugin
import DependencyPlugin
import DependencyPackagePlugin

let project = Project.makeModule(
  name: "FestiCoreSharedUI",
  dependencies: [.ui(.animation), .ui(.designSystem), .SPM.kingfisher],
  hasTests: true
)
