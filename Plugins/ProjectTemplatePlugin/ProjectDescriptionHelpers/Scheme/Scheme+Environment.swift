//
//  Scheme+Environment.swift
//  FestiCore
//

import ProjectDescription

public extension Scheme {
  static func appEnvironment(name: String, environment: BuildEnvironment, hasTests: Bool) -> Scheme {
    .scheme(
      name: "\(name)-\(environment.rawValue)",
      shared: true,
      buildAction: .buildAction(targets: [.target(name)]),
      testAction: hasTests ? .targets(
        [.testableTarget(target: .target("\(name)Tests"))],
        configuration: environment.configurationName,
        options: .options(coverage: true)
      ) : nil,
      runAction: .runAction(configuration: environment.configurationName),
      archiveAction: .archiveAction(configuration: environment.configurationName)
    )
  }
}
