//
//  TargetDependency+SPM.swift
//  FestiCore
//
//  Created by FestiCore on 10/22/26.
//

import ProjectDescription

public extension TargetDependency {
  enum SPM {}
}

public extension TargetDependency.SPM {
  static let alamofire = TargetDependency.external(name: "Alamofire")
  static let composableArchitecture = TargetDependency.external(name: "ComposableArchitecture")
  static let dependencies = TargetDependency.external(name: "Dependencies")
  static let sharing = TargetDependency.external(name: "Sharing")
  static let sqliteData = TargetDependency.external(name: "SQLiteData")
  static let tcaFlow = TargetDependency.external(name: "TCAFlow")
  static let concurrencyExtras = TargetDependency.external(name: "ConcurrencyExtras")
  static let sdwebImage = TargetDependency.external(name: "SDWebImageSwiftUI")
  static let googleSignIn = TargetDependency.external(name: "GoogleSignIn")
  static let firebaseCore = TargetDependency.external(name: "FirebaseCore")
  static let firebaseCrashlytics = TargetDependency.external(name: "FirebaseCrashlytics")
  static let kingfisher = TargetDependency.external(name: "Kingfisher")
}
