//
//  Tuist.swift
//  FestiCore
//
//  Created by FestiCore on 10/22/26.
//

import ProjectDescription

// 원격 컴파일 캐시(xcodeCache, enableCaching의 CAS 프록시)는 무료 Air 플랜 한도에 걸려 거부되며 빌드만 늦추므로 쓰지 않는다(#536, #551).
// fullHandle은 CI의 테스트 분할(shard plan)과 테스트 리포트에 필요해 남긴다.
// 캐시·프리뷰·분석 업로드 같은 부가 서버 단계는 저장소 변수 TUIST_SERVER_ENABLED가 true일 때만 CI에서 돈다.
let tuist = Tuist(
  fullHandle: "FestiCore/festicore",
  project: .tuist(
    compatibleXcodeVersions: .all,
    swiftVersion: .some("6.4.0"),
    plugins: [
      .local(path: .relativeToRoot("Plugins/ProjectTemplatePlugin")),
      .local(path: .relativeToRoot("Plugins/DependencyPackagePlugin")),
      .local(path: .relativeToRoot("Plugins/DependencyPlugin"))
    ],
    generationOptions: .options(
      optionalAuthentication: true,
      enableCaching: false
    ),
    installOptions: .options(),
    cacheOptions: .options(profiles: .profiles(default: .none))
  )
)
