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
      // HTTPS 등 표준 암호화만 사용한다. TestFlight 수출 규정 질문 없이 내부 배포되게 한다.
      .set("ITSAppUsesNonExemptEncryption", .boolean(false))
      .setUILaunchScreen()
      .setUISupportedInterfaceOrientations(["UIInterfaceOrientationPortrait"])
  )

  static let moduleInfoPlist: Self = .extendingDefault(with: InfoPlistDictionary())

  static let liveActivityWidgetInfoPlist: Self = .extendingDefault(
    with: InfoPlistDictionary()
      .set("CFBundleDisplayName", .string("$(FESTICORE_DISPLAY_NAME)"))
      .setCFBundleShortVersionString("$(FESTICORE_VERSION)")
      .setCFBundleVersion("$(FESTICORE_BUILD_NUMBER)")
      .setNSExtension(pointIdentifier: "com.apple.widgetkit-extension")
  )

  static let notificationServiceInfoPlist: Self = .extendingDefault(
    with: InfoPlistDictionary()
      .set("CFBundleDisplayName", .string("$(FESTICORE_DISPLAY_NAME)"))
      .setCFBundleShortVersionString("$(FESTICORE_VERSION)")
      .setCFBundleVersion("$(FESTICORE_BUILD_NUMBER)")
      .setNSExtension(
        pointIdentifier: "com.apple.usernotifications.service",
        principalClass: "$(PRODUCT_MODULE_NAME).NotificationService"
      )
  )
}
