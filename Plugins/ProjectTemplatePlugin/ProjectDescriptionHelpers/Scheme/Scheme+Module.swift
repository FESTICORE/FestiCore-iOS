//
//  Scheme+Module.swift
//  ProjectTemplatePlugin
//
//  Created by FestiCore on 10/23/26.
//

import ProjectDescription

public extension Scheme {
  static func module(name: String, hasTests: Bool) -> Scheme {
    makeModuleScheme(
      name: name,
      target: name,
      testTargets: hasTests ? ["\(name)Tests"] : []
    )
  }

  static func demo(name: String) -> Scheme {
    makeModuleScheme(name: name, target: name)
  }

  private static func makeModuleScheme(
    name: String,
    target: String,
    testTargets: [TestableTarget] = []
  ) -> Scheme {
    .scheme(
      name: name,
      shared: true,
      buildAction: .buildAction(targets: [.target(target)]),
      testAction: testTargets.isEmpty
        ? nil
        : .targets(
          testTargets,
          configuration: BuildEnvironment.stage.configurationName,
          options: .options(coverage: true)
        ),
      runAction: .runAction(configuration: BuildEnvironment.stage.configurationName),
      archiveAction: .archiveAction(configuration: BuildEnvironment.stage.configurationName)
    )
  }
}
