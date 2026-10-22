// swift-tools-version: 6.2
//
//  Package.swift
//  FestiCore
//
//  Created by FestiCore on 10/22/26.
//

import PackageDescription

#if TUIST
import ProjectDescription

let packageSettings = PackageSettings(
  productTypes: [
    "Alamofire": .framework,
    "ComposableArchitecture": .framework,
    "Dependencies": .framework,
    "DependenciesMacros": .framework,
    "IssueReporting": .framework,
    "IssueReportingPackageSupport": .framework,
    "XCTestDynamicOverlay": .framework,
    "Perception": .framework,
    "PerceptionCore": .framework,
    "Sharing": .framework,
    "SQLiteData": .framework,
    "GRDB": .framework,
    "GRDBSQLite": .framework,
    "GRDB_GRDB": .framework,
    "StructuredQueries": .framework,
    "StructuredQueriesCore": .framework,
    "StructuredQueriesSQLite": .framework,
    "StructuredQueriesSQLiteCore": .framework,
    "TCAFlow": .framework,
    "SDWebImageSwiftUI": .framework,
    "GoogleSignIn": .framework,
    "FirebaseCore": .framework,
    "FirebaseCrashlytics": .framework,
    "Kingfisher": .framework
  ],
  baseSettings: .settings(configurations: [
    .debug(name: "Stage"),
    .release(name: "Prod")
  ])
)
#endif

let package = Package(
  name: "FestiCore",
  dependencies: [
    .package(url: "https://github.com/firebase/firebase-ios-sdk", exact: "12.12.0"),
    .package(url: "https://github.com/google/GoogleSignIn-iOS", exact: "9.2.0"),
    .package(url: "https://github.com/SDWebImage/SDWebImageSwiftUI.git", exact: "3.1.4"),
    .package(url: "https://github.com/pointfreeco/swift-composable-architecture", exact: "1.26.2"),
    .package(url: "https://github.com/pointfreeco/xctest-dynamic-overlay", exact: "1.11.0"),
    .package(url: "https://github.com/pointfreeco/sqlite-data", exact: "1.11.0"),
    .package(url: "https://github.com/pointfreeco/swift-structured-queries", exact: "0.36.0"),
    .package(url: "https://github.com/Roy-wonji/TCAFlow.git", exact: "1.2.0"),
    .package(url: "https://github.com/openid/AppAuth-iOS.git", exact: "2.1.0"),
    .package(url: "https://github.com/Alamofire/Alamofire", exact: "5.12.0"),
    .package(url: "https://github.com/onevcat/Kingfisher.git", exact: "8.14.0")
  ]
)
