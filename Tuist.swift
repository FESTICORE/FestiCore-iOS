//
//  Tuist.swift
//  FestiCore
//
//  Created by FestiCore on 10/22/26.
//

import ProjectDescription

// Tuist 서버(원격 캐시·Insights·Previews)는 플랜 사용량과 요금이 생기지 않도록 기본으로 끈다(#536).
// fullHandle과 xcodeCache를 두지 않아 로컬·CI 빌드는 로컬 캐시만 쓰고 서버에 올리지 않는다.
// 다시 켜려면 플랜을 확인한 뒤 fullHandle: "FestiCore/festicore"와 xcodeCache를 되돌리고 저장소 변수 TUIST_SERVER_ENABLED를 true로 둔다.
let tuist = Tuist(
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
