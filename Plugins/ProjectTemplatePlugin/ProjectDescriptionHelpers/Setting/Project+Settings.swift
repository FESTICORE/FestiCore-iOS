//
//  Project+Settings.swift
//  FestiCore
//
//  Created by FestiCore on 10/22/26.
//

import ProjectDescription

public extension Settings {
  static var appMainSettings: Settings {
    .settings(
      base: [
        "AS_AUTHENTICATION_SERVICES_ENABLED": "YES",
        "CODE_SIGN_STYLE": "Manual",
        "DEVELOPMENT_TEAM": .string(Project.Environment.organizationTeamId),
        "MARKETING_VERSION": "$(FESTICORE_VERSION)",
        "CURRENT_PROJECT_VERSION": "$(FESTICORE_BUILD_NUMBER)",
        // 앱도 모듈과 같이 Point-Free Sharing을 별칭으로 가져온다(딥링크 대기 저장소의 @Shared).
        "OTHER_SWIFT_FLAGS": "$(inherited) -module-alias Sharing=FestiCorePointFreeSharing"
      ],
      configurations: [
        .debug(
          name: BuildEnvironment.stage.configurationName,
          settings: [
            "FESTICORE_APNS_ENVIRONMENT": "development",
            "PROVISIONING_PROFILE_SPECIFIER": .string("match Development \(Project.Environment.mainBundleId)")
          ],
          xcconfig: BuildEnvironment.stage.xcconfigPath
        ),
        .release(
          name: BuildEnvironment.prod.configurationName,
          settings: [
            "FESTICORE_APNS_ENVIRONMENT": "production",
            "PROVISIONING_PROFILE_SPECIFIER": .string("match AppStore \(Project.Environment.mainBundleId)")
          ],
          xcconfig: BuildEnvironment.prod.xcconfigPath
        )
      ]
    )
  }

  /// 테스트 번들은 앱의 match 수동 프로파일(번들 ID가 다르다)을 물려받지 않고 자동 서명한다. 실기기 테스트에 필요하다.
  static func testSigningSettings(_ base: SettingsDictionary = [:]) -> Settings {
    return .settings(base: base.merging([
      "CODE_SIGN_STYLE": "Automatic",
      "DEVELOPMENT_TEAM": .string(Project.Environment.organizationTeamId),
      "PROVISIONING_PROFILE_SPECIFIER": ""
    ]) { current, _ in current })
  }

  static var moduleSettings: Settings {
    .settings(base: [
      "OTHER_SWIFT_FLAGS": "$(inherited) -module-alias Sharing=FestiCorePointFreeSharing"
    ], configurations: [
      .debug(name: BuildEnvironment.stage.configurationName, xcconfig: BuildEnvironment.stage.xcconfigPath),
      .release(name: BuildEnvironment.prod.configurationName, xcconfig: BuildEnvironment.prod.xcconfigPath)
    ])
  }
}
