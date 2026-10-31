//
//  Project.swift
//  FestiCoreDesignKit
//
//  Created by FestiCore on 10/22/26.
//

import ProjectDescription
import ProjectTemplatePlugin
import DependencyPackagePlugin
import DependencyPlugin

let project = Project.makeModule(
  name: "FestiCoreDesignKit",
  product: .framework,
  sources: ["Sources/**"],
  resources: ["Resources/**"],
  testResources: ["Tests/Resources/**"],
  hasTests: true,
  hasDemo: true,
  demoDependencies: [.ui(.sharedUI), .SPM.composableArchitecture]
)
