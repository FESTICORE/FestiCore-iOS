//
//  Project+Template.swift
//  FestiCore
//
//  Created by FestiCore on 10/22/26.
//

import ProjectDescription

public extension Project {
  static func makeAppModule(
    name: String = Environment.appName,
    bundleId: String = Environment.mainBundleId,
    settings: Settings = .moduleSettings,
    dependencies: [TargetDependency] = [],
    infoPlist: InfoPlist = .default,
    hasTests: Bool = false
  ) -> Project {
    let appTarget: Target = .target(
      name: name,
      destinations: Environment.deploymentDestination,
      product: .app,
      bundleId: bundleId,
      deploymentTargets: Environment.deploymentTarget,
      infoPlist: infoPlist,
      sources: ["Sources/**"],
      dependencies: dependencies,
      settings: .settings(base: [
        "DEVELOPMENT_TEAM": .string(Environment.organizationTeamId),
        "TARGETED_DEVICE_FAMILY": "1",
        "SWIFT_VERSION": "6.0",
        "MARKETING_VERSION": "$(FESTICORE_VERSION)",
        "CURRENT_PROJECT_VERSION": "$(FESTICORE_BUILD_NUMBER)"
      ])
    )
    var targets = [appTarget]
    if hasTests {
      targets.append(.target(
        name: "\(name)Tests",
        destinations: Environment.deploymentDestination,
        product: .unitTests,
        bundleId: "\(bundleId).tests",
        deploymentTargets: Environment.deploymentTarget,
        infoPlist: .default,
        sources: ["Tests/**"],
        dependencies: [.target(name: name)]
      ))
    }
    return Project(
      name: name,
      settings: settings,
      targets: targets,
      schemes: [
        .appEnvironment(name: name, environment: .prod, hasTests: false)
      ]
    )
  }

  static func makeModule(
    name: String,
    dependencies: [TargetDependency] = [],
    hasTests: Bool = false
  ) -> Project {
    var targets: [Target] = [
      .target(
        name: name,
        destinations: Environment.deploymentDestination,
        product: .staticFramework,
        bundleId: .appBundleID(name: name),
        deploymentTargets: Environment.deploymentTarget,
        infoPlist: .moduleInfoPlist,
        sources: ["Sources/**"],
        dependencies: dependencies
      )
    ]

    if hasTests {
      targets.append(.target(
        name: "\(name)Tests",
        destinations: Environment.deploymentDestination,
        product: .unitTests,
        bundleId: .appBundleID(name: "\(name)Tests"),
        deploymentTargets: Environment.deploymentTarget,
        infoPlist: .default,
        sources: ["Tests/**"],
        dependencies: [.target(name: name)]
      ))
    }

    return Project(name: name, settings: .moduleSettings, targets: targets)
  }
}
