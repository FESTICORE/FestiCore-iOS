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
    upload: Environment.isCI
  ),
  // CI만 컴파일 캐시를 업로드하고 로컬 빌드는 내려받아 사용한다.
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
