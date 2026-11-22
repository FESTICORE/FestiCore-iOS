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

  /// Stage는 로컬 디버깅용이라 최적화를 끈다. TestFlight로 나가는 Stage 빌드만 `FESTICORE_STAGE_OPTIMIZE=YES`로 켠다(#626).
  /// 최적화를 xcargs로 넘기면 SPM 패키지까지 적용돼 Swift 6.4가 swift-issue-reporting을 컴파일하다 크래시한다(#641).
  /// 그래서 archive에 들어가는 우리 타깃에만 둔다. Tuist의 타깃 기본값(-Onone 등)을 덮도록 타깃 수준에 넣는다.
  static var stageOptimizationSettings: SettingsDictionary {
    return [
      "FESTICORE_STAGE_OPTIMIZE": "NO",
      "FESTICORE_STAGE_SWIFT_OPTIMIZATION_LEVEL_NO": "-Onone",
      "FESTICORE_STAGE_SWIFT_OPTIMIZATION_LEVEL_YES": "-O",
      "FESTICORE_STAGE_SWIFT_COMPILATION_MODE_NO": "singlefile",
      "FESTICORE_STAGE_SWIFT_COMPILATION_MODE_YES": "wholemodule",
      "FESTICORE_STAGE_GCC_OPTIMIZATION_LEVEL_NO": "0",
      "FESTICORE_STAGE_GCC_OPTIMIZATION_LEVEL_YES": "s",
      "SWIFT_OPTIMIZATION_LEVEL": "$(FESTICORE_STAGE_SWIFT_OPTIMIZATION_LEVEL_$(FESTICORE_STAGE_OPTIMIZE))",
      "SWIFT_COMPILATION_MODE": "$(FESTICORE_STAGE_SWIFT_COMPILATION_MODE_$(FESTICORE_STAGE_OPTIMIZE))",
      "GCC_OPTIMIZATION_LEVEL": "$(FESTICORE_STAGE_GCC_OPTIMIZATION_LEVEL_$(FESTICORE_STAGE_OPTIMIZE))"
    ]
  }

  /// archive에 들어가는 앱 · 모듈 타깃 설정. Stage 구성에 TestFlight 최적화 스위치를 붙인다.
  static func archivedTargetSettings(_ base: SettingsDictionary = [:]) -> Settings {
    return .settings(
      base: base,
      configurations: [
        .debug(
          name: BuildEnvironment.stage.configurationName,
          settings: stageOptimizationSettings
        ),
        .release(name: BuildEnvironment.prod.configurationName)
      ]
    )
  }
}
