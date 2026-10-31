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
import Foundation

// XCTest가 로드하는 Apple Sharing 모듈과 Point-Free Sharing 제품의 이름 충돌을 막는다.
private let packageBaseSettings: Settings = .settings(
  base: ["OTHER_SWIFT_FLAGS": "$(inherited) -module-alias Sharing=FestiCorePointFreeSharing"],
  configurations: [.debug(name: "Stage"), .release(name: "Prod")]
)

let packageSettings = PackageSettings(
  productTypes: [
    "Alamofire": .framework,
    "ComposableArchitecture": .framework,
    "ConcurrencyExtras": .framework,
    "Dependencies": .framework,
    "DependenciesMacros": .framework,
    "IssueReporting": .framework,
    "IssueReportingPackageSupport": .framework,
    "XCTestDynamicOverlay": .framework,
    "Perception": .framework,
    "PerceptionCore": .framework,
    "Sharing": .framework,
    "Sharing1": .staticFramework,
    "Sharing2": .staticFramework,
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
    "Kingfisher": .framework,
    "SVGKit": .framework,
    "Mixpanel": .framework,
    "Sentry-Static": .staticFramework
  ],
  baseSettings: packageBaseSettings,
  targetSettings: [
    "Sharing": .settings(base: ["PRODUCT_NAME": "FestiCorePointFreeSharing"]),
    // xctest-dynamic-overlay 호환 타깃과 swift-issue-reporting의 출력 이름 충돌을 피한다.
    "_IssueReporting": .settings(base: ["PRODUCT_NAME": "FestiCoreIssueReportingCompatibility"]),
    // SVGKit은 모르는 기기(arm64 시뮬레이터·신형 iPhone)의 PPI를 NSAssert로 막아 SVG 파싱이 실패한다.
    "SVGKit": .settings(base: ["ENABLE_NS_ASSERTIONS": "NO"])
  ]
)
#endif

let package = Package(
  name: "FestiCore",
  dependencies: [
    .package(url: "https://github.com/firebase/firebase-ios-sdk", exact: "12.12.0"),
    .package(url: "https://github.com/google/GoogleSignIn-iOS", exact: "9.2.0"),
    .package(url: "https://github.com/SDWebImage/SDWebImageSwiftUI.git", exact: "3.1.4"),
    .package(url: "https://github.com/pointfreeco/swift-composable-architecture", exact: "1.26.2"),
    .package(url: "https://github.com/pointfreeco/xctest-dynamic-overlay", exact: "1.13.1"),
    .package(url: "https://github.com/pointfreeco/sqlite-data", exact: "1.11.0"),
    .package(url: "https://github.com/pointfreeco/swift-structured-queries", exact: "0.36.0"),
    .package(url: "https://github.com/Roy-wonji/TCAFlow.git", exact: "1.2.0"),
    .package(url: "https://github.com/openid/AppAuth-iOS.git", exact: "2.1.0"),
    .package(url: "https://github.com/Alamofire/Alamofire", exact: "5.12.0"),
    .package(url: "https://github.com/onevcat/Kingfisher.git", exact: "8.14.0"),
    .package(url: "https://github.com/SVGKit/SVGKit.git", exact: "3.0.0"),
    .package(url: "https://github.com/airbnb/lottie-spm.git", exact: "4.5.2"),
    .package(url: "https://github.com/mixpanel/mixpanel-swift.git", exact: "7.0.0"),
    .package(url: "https://github.com/getsentry/sentry-apple-binaries.git", exact: "9.30.1")
  ]
)
