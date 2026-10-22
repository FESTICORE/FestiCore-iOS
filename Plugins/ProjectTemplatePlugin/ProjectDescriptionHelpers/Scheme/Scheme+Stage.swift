//
//  Scheme+Stage.swift
//  FestiCore
//
//  Created by FestiCore on 10/22/26.
//

import Foundation
import ProjectDescription

public extension Scheme {
  static func stageWorkspace(name: String) -> Scheme {
    let root = URL(fileURLWithPath: #filePath)
      .deletingLastPathComponent()
      .deletingLastPathComponent()
      .deletingLastPathComponent()
      .deletingLastPathComponent()
      .deletingLastPathComponent()
    let moduleTests: [TestableTarget] = ["Feature", "Domain", "Data", "Core", "UI"].flatMap { layer in
      let directory = root.appendingPathComponent("Projects/\(layer)")
      let modules = (try? FileManager.default.contentsOfDirectory(
        at: directory,
        includingPropertiesForKeys: [.isDirectoryKey]
      )) ?? []
      return modules.sorted { $0.lastPathComponent < $1.lastPathComponent }.compactMap { module -> TestableTarget? in
        guard FileManager.default.fileExists(atPath: module.appendingPathComponent("Project.swift").path),
              FileManager.default.fileExists(atPath: module.appendingPathComponent("Tests").path) else {
          return nil
        }
        let name = module.lastPathComponent
        return .testableTarget(target: .project(path: "Projects/\(layer)/\(name)", target: "\(name)Tests"))
      }
    }
    let appTarget = TargetReference.project(path: "Projects/App", target: name)
    return .scheme(
      name: "\(name)-Stage",
      shared: true,
      buildAction: .buildAction(targets: [appTarget]),
      testAction: .targets(
        [.testableTarget(target: .project(path: "Projects/App", target: "\(name)Tests"))] + moduleTests,
        configuration: BuildEnvironment.stage.configurationName,
        options: .options(coverage: true)
      ),
      runAction: .runAction(configuration: BuildEnvironment.stage.configurationName, executable: appTarget),
      archiveAction: .archiveAction(configuration: BuildEnvironment.stage.configurationName)
    )
  }
}
