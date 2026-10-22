//
//  Project+InfoPlist.swift
//  FestiCore
//
//  Created by FestiCore on 10/22/26.
//

import ProjectDescription

public extension InfoPlist {
  static let appInfoPlist: Self = .extendingDefault(
    with: InfoPlistDictionary()
      .setCFBundleName("$(FESTICORE_DISPLAY_NAME)")
      .setCFBundleShortVersionString("$(FESTICORE_VERSION)")
      .setCFBundleVersion("$(FESTICORE_BUILD_NUMBER)")
      .setFestiCoreEnvironment("$(FESTICORE_ENVIRONMENT)")
      .setFestiCoreAPIHost("$(FESTICORE_API_HOST)")
      .setUILaunchScreen()
      .setUISupportedInterfaceOrientations(["UIInterfaceOrientationPortrait"])
  )

  static let moduleInfoPlist: Self = .extendingDefault(with: InfoPlistDictionary())
}
