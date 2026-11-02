//
//  AnalyticsEvent+Payload.swift
//  FestiCoreAnalytics
//
//  Created by FestiCore on 11/2/26.
//

import FestiCoreAnalyticsInterface

extension AnalyticsEvent {
  var name: String {
    switch self {
    case .screenView: "screen_view"
    }
  }

  var properties: [String: String] {
    switch self {
    case let .screenView(screen): ["screen": screen.rawValue]
    }
  }

  /// 화면 이동은 Sentry breadcrumb의 navigation 분류로 남긴다.
  var breadcrumbCategory: String {
    switch self {
    case .screenView: "navigation"
    }
  }
}
