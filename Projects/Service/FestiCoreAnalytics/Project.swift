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
    .SPM.firebaseCore,
    .SPM.firebaseAnalyticsCore,
    .core(.logger),
    .core(
      .storage,
      .interface
    ),
    .SPM.mixpanel,
    .SPM.sentry
  ],
  targetSettings: [
    "OTHER_LDFLAGS": "$(inherited) -ObjC"
  ],
  hasTests: true,
  testDependencies: [.service(.config)],
  hasInterface: true,
  interfaceDependencies: [
    .SPM.composableArchitecture
  ]
)
