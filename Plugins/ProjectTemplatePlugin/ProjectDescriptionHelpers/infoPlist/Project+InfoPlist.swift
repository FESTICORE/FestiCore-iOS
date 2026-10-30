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
      .set("CFBundleDisplayName", .string("$(FESTICORE_DISPLAY_NAME)"))
      .setCFBundleShortVersionString("$(FESTICORE_VERSION)")
      .setCFBundleVersion("$(FESTICORE_BUILD_NUMBER)")
      .setFestiCoreEnvironment("$(FESTICORE_ENVIRONMENT)")
      .set("FestiCoreAPNsEnvironment", .string("$(FESTICORE_APNS_ENVIRONMENT)"))
      .setFestiCoreAPIHost("$(FESTICORE_API_HOST)")
      .set("GIDClientID", .string("$(GOOGLE_IOS_CLIENT_ID)"))
      .set("GIDServerClientID", .string("$(GOOGLE_CLIENT_ID)"))
      .set("CFBundleURLTypes", .array([
        .dictionary([
          "CFBundleURLName": .string("google-oauth"),
          "CFBundleURLSchemes": .array([
            .string("$(REVERSED_CLIENT_ID)")
          ])
        ])
      ]))
      .setFestiCoreMixpanelToken("$(FESTICORE_MIXPANEL_TOKEN)")
      .setFestiCoreSentryDSN("$(FESTICORE_SENTRY_DSN)")
      .set("NSSupportsLiveActivities", .boolean(true))
      .setUILaunchScreen()
      .setUISupportedInterfaceOrientations(["UIInterfaceOrientationPortrait"])
  )

  static let moduleInfoPlist: Self = .extendingDefault(with: InfoPlistDictionary())

  static let liveActivityWidgetInfoPlist: Self = .extendingDefault(
    with: InfoPlistDictionary()
      .set("CFBundleDisplayName", .string("FestiCore"))
      .setCFBundleShortVersionString("$(FESTICORE_VERSION)")
      .setCFBundleVersion("$(FESTICORE_BUILD_NUMBER)")
      .setNSExtension(pointIdentifier: "com.apple.widgetkit-extension")
  )

  static let notificationServiceInfoPlist: Self = .extendingDefault(
    with: InfoPlistDictionary()
      .setCFBundleShortVersionString("$(FESTICORE_VERSION)")
      .setCFBundleVersion("$(FESTICORE_BUILD_NUMBER)")
      .setNSExtension(
        pointIdentifier: "com.apple.usernotifications.service",
        principalClass: "$(PRODUCT_MODULE_NAME).NotificationService"
      )
  )
}
