//
//  InfoPlistDictionary.swift
//  FestiCore
//
//  Created by FestiCore on 10/22/26.
//

import ProjectDescription

public typealias InfoPlistDictionary = [String: Plist.Value]

extension InfoPlistDictionary {
  func set(_ key: String, _ value: Plist.Value) -> Self {
    merging([key: value]) { _, new in new }
  }

  func setCFBundleName(_ value: String) -> Self { set("CFBundleName", .string(value)) }
  func setCFBundleShortVersionString(_ value: String) -> Self { set("CFBundleShortVersionString", .string(value)) }
  func setCFBundleVersion(_ value: String) -> Self { set("CFBundleVersion", .string(value)) }
  func setFestiCoreEnvironment(_ value: String) -> Self { set("FestiCoreEnvironment", .string(value)) }
  func setFestiCoreAPIHost(_ value: String) -> Self { set("FestiCoreAPIHost", .string(value)) }
  func setFestiCoreMixpanelToken(_ value: String) -> Self { set("FestiCoreMixpanelToken", .string(value)) }
  func setUILaunchScreen() -> Self { set("UILaunchScreen", .dictionary([:])) }
  func setUISupportedInterfaceOrientations(_ values: [String]) -> Self {
    set("UISupportedInterfaceOrientations", .array(values.map(Plist.Value.string)))
  }
}
