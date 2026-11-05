//
//  AnalyticsUseCase+Live.swift
//  FestiCoreAnalytics
//
//  Created by FestiCore on 11/3/26.
//

import Foundation

import ComposableArchitecture
import FestiCoreAnalyticsInterface
import FestiCoreLogger
import Mixpanel
@preconcurrency import Sentry

// MARK: - Live

extension AnalyticsUseCase: DependencyKey {
  /// 모든 이벤트에 자동 첨부되는 공통 슈퍼 프로퍼티(플랫폼/버전). is_logged_in은 identify/reset이 관리.
  public static func baseSuperProperties() -> Properties {
    let info = Bundle.main.infoDictionary
    return [
      "os_type": "ios",
      "app_version": (info?["CFBundleShortVersionString"] as? String) ?? "",
      "build": (info?["CFBundleVersion"] as? String) ?? ""
    ]
  }

  /// 토큰이 없어 Mixpanel을 시작하지 않았으면 `safeMainInstance()`가 nil이라 보내지 않는다.
  /// Sentry도 시작하지 않았으면 호출이 무시된다.
  public static let liveValue = AnalyticsUseCase(
    registerBaseProperties: {
      Mixpanel.safeMainInstance()?.registerSuperProperties(baseSuperProperties())
    },
    identify: { userID, method in
      guard !userID.isEmpty else { return }

      if let mixpanel = Mixpanel.safeMainInstance() {
        mixpanel.identify(distinctId: userID)

        // 로그인 컨텍스트를 슈퍼 프로퍼티로 등록 → 이후 모든 이벤트에 자동 첨부.
        var superProps: Properties = ["is_logged_in": true]
        if let method, !method.isEmpty {
          superProps["login_provider"] = method
          mixpanel.people.set(properties: ["provider": method])
        }
        mixpanel.registerSuperProperties(superProps)
      }

      // Sentry 이슈에도 같은 사용자를 붙여 Mixpanel과 같은 ID로 대조한다.
      let user = User(userId: userID)
      if let method, !method.isEmpty {
        user.data = ["login_provider": method]
      }
      SentrySDK.setUser(user)
    },
    track: { event in
      let name = eventName(event)
      let properties = eventProperties(event)
      FestiCoreLogger.debug(
        "Mixpanel track — event: \(name), properties: \(String(describing: properties))",
        category: .app)
      Mixpanel.safeMainInstance()?.track(
        event: name,
        properties: properties)
      monitorInSentry(
        name: name,
        properties: properties)
    },
    reset: {
      if let mixpanel = Mixpanel.safeMainInstance() {
        mixpanel.reset() // 슈퍼 프로퍼티 포함 전체 초기화 → 계정 분리.
        mixpanel.registerSuperProperties(baseSuperProperties()) // 공통 프로퍼티 재등록(is_logged_in 미포함 = 로그아웃).
      }
      SentrySDK.setUser(nil) // 다음 이슈가 이전 계정에 붙지 않도록 함께 끊는다.
    }
  )

  /// 추적한 사용자 동작을 Sentry에도 남긴다. breadcrumb는 이슈 맥락, 카운트는 추이용이다.
  /// 앱 로그를 Sentry Logs로 보내는 일은 `SentryLogSink`가 따로 맡는다.
  private static func monitorInSentry(name: String, properties: Properties) {
    let breadcrumb = Breadcrumb(
      level: .info,
      category: "user.action")
    breadcrumb.message = name
    for (
      key,
      value) in properties {
      breadcrumb.setData(
        value: value,
        key: key
      )
    }
    SentrySDK.addBreadcrumb(breadcrumb)

    var metricAttributes: [String: any SentryAttributeValue] = ["event": name]
    for (
      key,
      value) in properties.compactMapValues({ $0 as? String }) {
      metricAttributes[key] = value
    }
    SentrySDK.metrics.count(
      key: "user.action.count",
      value: 1,
      attributes: metricAttributes)
  }

  static func eventName(_ event: AnalyticsEvent) -> String {
    switch event {
    case .signUp: "sign_up"
    case .screenView: "screen_view"
    case .uiAction: "ui_action"
    case .flagFollow: "flag_follow"
    case .timetableAction: "timetable_action"
    case .packSync: "pack_sync"
    }
  }

  static func eventProperties(_ event: AnalyticsEvent) -> Properties {
    switch event {
    case let .signUp(method):
      return ["method": method.rawValue]

    case let .screenView(
      screen,
      referrer):
      var properties: Properties = ["screen": screen.rawValue]
      if let referrer {
        properties["referrer"] = referrer.rawValue
      }
      return properties

    case let .uiAction(
      action,
      screen):
      return ["action": action.rawValue, "screen": screen.rawValue]

    case let .flagFollow(data):
      return ["flag_id": data.flagID, "is_following": data.isFollowing]

    case let .timetableAction(data):
      var properties: Properties = [
        "action": data.action.rawValue,
        "festival_id": data.festivalID
      ]
      if let setID = data.setID {
        properties["set_id"] = setID
      }
      return properties

    case let .packSync(data):
      return ["festival_id": data.festivalID, "result": data.result.rawValue]
    }
  }
}
