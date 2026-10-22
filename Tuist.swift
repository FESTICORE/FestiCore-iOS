//
//  Tuist.swift
//  FestiCore
//
//  Created by FestiCore on 10/22/26.
//

import Foundation
import ProjectDescription

let tuist = Tuist(
  fullHandle: "suhwj81/festicore",
  xcodeCache: .xcodeCache(
    upload: Environment.isCI && !(ProcessInfo.processInfo.environment["TUIST_TOKEN"] ?? "").isEmpty
  ),
  project: .tuist(
    compatibleXcodeVersions: .all,
    swiftVersion: .some("6.4.0"),
    plugins: [
      .local(path: .relativeToRoot("Plugins/ProjectTemplatePlugin")),
      .local(path: .relativeToRoot("Plugins/DependencyPackagePlugin")),
      .local(path: .relativeToRoot("Plugins/DependencyPlugin"))
    ],
    generationOptions: .options(optionalAuthentication: true, enableCaching: true),
    installOptions: .options(),
    cacheOptions: .options(profiles: .profiles(default: .none))
  )
)
