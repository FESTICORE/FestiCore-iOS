//
//  Scheme+Stage.swift
//  FestiCore
//
//  Created by FestiCore on 10/22/26.
//

import ProjectDescription

public extension Scheme {
  static func stageWorkspace(name: String) -> Scheme {
    let appTarget = TargetReference.project(path: "Projects/App", target: name)
    return .scheme(
      name: "\(name)-Stage",
      shared: true,
      buildAction: .buildAction(targets: [appTarget]),
      testAction: .testPlans(
        [.relativeToRoot("Projects/App/Tests/FestiCore.xctestplan")],
        configuration: BuildEnvironment.stage.configurationName
      ),
      runAction: .runAction(configuration: BuildEnvironment.stage.configurationName, executable: appTarget),
      archiveAction: .archiveAction(configuration: BuildEnvironment.stage.configurationName)
    )
  }
}
