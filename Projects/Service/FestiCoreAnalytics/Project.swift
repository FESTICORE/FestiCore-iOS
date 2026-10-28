//
//  Project.swift
//  FestiCoreAnalytics
//
//  Created by FestiCore on 10/28/26.
//

import DependencyPackagePlugin
import DependencyPlugin
import ProjectDescription
import ProjectTemplatePlugin

let project = Project.makeModule(
  name: "FestiCoreAnalytics",
  product: .framework,
  dependencies: [
    .core(.logger),
    .SPM.mixpanel,
    .SPM.sentry
  ],
  hasTests: true
)
