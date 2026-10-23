//
//  Project.swift
//  FeatureAssembly
//
//  Created by FestiCore on 10/23/26.
//

import DependencyPackagePlugin
import DependencyPlugin
import ProjectDescription
import ProjectTemplatePlugin

let project = Project.makeModule(
  name: "FeatureAssembly",
  dependencies: [
    .feature(.home),
    .service(.assembly),
    .SPM.composableArchitecture
  ]
)
