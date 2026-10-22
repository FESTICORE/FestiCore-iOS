//
//  Tuist.swift
//  FestiCore
//
//  Created by FestiCore on 10/22/26.
//

import ProjectDescription

let tuist = Tuist(
  fullHandle: "FestiCore/festicore",
  xcodeCache: .xcodeCache(
    upload: Environment.isCI
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
