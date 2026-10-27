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
    sources _: SourceFilesList = ["Sources/**"],
    resources: ResourceFileElements? = nil,
    infoPlist: InfoPlist = .default,
    entitlements: Entitlements? = nil,
    hasTests: Bool = false
  ) -> Project {
    let appTarget: Target = .target(
      name: name,
      destinations: Environment.deploymentDestination,
      product: .app,
      bundleId: bundleId,
      deploymentTargets: Environment.deploymentTarget,
      infoPlist: infoPlist,
      buildableFolders: resources != nil ? ["Sources", "Resources"] : ["Sources"],
      entitlements: entitlements,
      dependencies: dependencies,
      settings: .settings(base: [
        "TARGETED_DEVICE_FAMILY": "1",
        "SWIFT_VERSION": "6.0"
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
        buildableFolders: ["Tests/Sources"],
        dependencies: [.target(name: name)]
      ))
    }
    return Project(
      name: name,
      options: .options(
        automaticSchemesOptions: .enabled(codeCoverageEnabled: true),
        defaultKnownRegions: ["en", "ko"],
        developmentRegion: "ko"
      ),
      settings: settings,
      targets: targets,
      schemes: [
        .appEnvironment(name: name, environment: .prod, hasTests: false)
      ],
      additionalFiles: hasTests ? ["Tests/*.xctestplan"] : []
    )
  }

  static func makeModule(
    name: String,
    product: Product = .staticFramework,
    dependencies: [TargetDependency] = [],
    targetSettings: Settings? = nil,
    sources _: SourceFilesList = ["Sources/**"],
    resources: ResourceFileElements? = nil,
    testResources _: ResourceFileElements? = nil,
    hasTests: Bool = false,
    hasInterface: Bool = false,
    interfaceDependencies: [TargetDependency] = [],
    hasDemo: Bool = false
  ) -> Project {
    var targets: [Target] = []

    if hasInterface {
      targets.append(.target(
        name: "\(name)Interface",
        destinations: Environment.deploymentDestination,
        product: product,
        bundleId: .appBundleID(name: "\(name)Interface"),
        deploymentTargets: Environment.deploymentTarget,
        infoPlist: .moduleInfoPlist,
        buildableFolders: ["Interface"],
        dependencies: interfaceDependencies
      ))
    }

    targets.append(.target(
        name: name,
        destinations: Environment.deploymentDestination,
        product: product,
        bundleId: .appBundleID(name: name),
        deploymentTargets: Environment.deploymentTarget,
        infoPlist: .moduleInfoPlist,
        buildableFolders: resources != nil ? ["Sources", "Resources"] : ["Sources"],
        dependencies: (hasInterface ? [.target(name: "\(name)Interface")] : []) + dependencies,
        settings: targetSettings
      ))

    if hasDemo {
      targets.append(.target(
        name: "\(name)Demo",
        destinations: Environment.deploymentDestination,
        product: .app,
        bundleId: .appBundleID(name: "\(name)Demo"),
        deploymentTargets: Environment.deploymentTarget,
        infoPlist: .default,
        buildableFolders: ["Demo"],
        dependencies: [.target(name: name)]
      ))
    }

    if hasTests {
      targets.append(.target(
        name: "\(name)Tests",
        destinations: Environment.deploymentDestination,
        product: .unitTests,
        bundleId: .appBundleID(name: "\(name)Tests"),
        deploymentTargets: Environment.deploymentTarget,
        infoPlist: .default,
        buildableFolders: ["Tests"],
        dependencies: [.target(name: name)] + (hasInterface ? [.target(name: "\(name)Interface")] : [])
      ))
    }

    let schemes: [Scheme] = hasDemo ? [
      .module(name: name, hasTests: hasTests),
      .demo(name: "\(name)Demo")
    ] : []

    return Project(
      name: name,
      options: .options(
        automaticSchemesOptions: hasDemo ? .disabled : .enabled(codeCoverageEnabled: true),
        defaultKnownRegions: ["en", "ko"],
        developmentRegion: "ko"
      ),
      settings: .moduleSettings,
      targets: targets,
      schemes: schemes
    )
  }

  static func makeAppExtensionModule(
    name: String,
    targetName: String,
    bundleId: String,
    infoPlist: InfoPlist,
    dependencies: [TargetDependency] = []
  ) -> Project {
    Project(
      name: name,
      settings: .moduleSettings,
      targets: [
        .target(
          name: targetName,
          destinations: Environment.deploymentDestination,
          product: .appExtension,
          bundleId: bundleId,
          deploymentTargets: Environment.deploymentTarget,
          infoPlist: infoPlist,
          buildableFolders: ["Extension"],
          dependencies: dependencies,
          settings: .settings(base: [
            "APPLICATION_EXTENSION_API_ONLY": "YES",
            "CODE_SIGN_STYLE": "Manual",
            "DEVELOPMENT_TEAM": .string(Environment.organizationTeamId)
          ], configurations: [
            .debug(
              name: BuildEnvironment.stage.configurationName,
              settings: ["PROVISIONING_PROFILE_SPECIFIER": .string("match Development \(bundleId)")],
              xcconfig: BuildEnvironment.stage.xcconfigPath
            ),
            .release(
              name: BuildEnvironment.prod.configurationName,
              settings: ["PROVISIONING_PROFILE_SPECIFIER": .string("match AppStore \(bundleId)")],
              xcconfig: BuildEnvironment.prod.xcconfigPath
            )
          ])
        )
      ]
    )
  }
}
