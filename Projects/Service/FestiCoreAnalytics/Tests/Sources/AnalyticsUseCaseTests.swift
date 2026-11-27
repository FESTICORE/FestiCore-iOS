//
//  AnalyticsUseCaseTests.swift
//  FestiCoreAnalyticsTests
//
//  Created by FestiCore on 11/3/26.
//

import ComposableArchitecture
import FestiCoreAnalyticsInterface
import Testing
@testable import FestiCoreAnalytics

struct AnalyticsUseCaseTests {
  @Test func consentGatesFirebaseEventsAndIdentityButResetAlwaysRuns() {
    let enabled = LockIsolated(true)
    let calls = LockIsolated<[String]>([])
    let firebase = AnalyticsUseCase(
      registerBaseProperties: { calls.withValue { $0.append("base") } },
      identify: { id, method in calls.withValue { $0.append("identify:\(id):\(method ?? "")") } },
      track: { event in calls.withValue { $0.append(AnalyticsUseCase.eventName(event)) } },
      reset: { calls.withValue { $0.append("reset") } }
    )
    let live = AnalyticsUseCase.makeLiveValue(
      firebase: firebase,
      collectionEnabled: { enabled.value }
    )
    live.registerBaseProperties()
    live.identify(
      "test-user",
      "apple"
    )
    live.track(.screenView(
      screen: .profile,
      referrer: nil
    ))
    enabled.setValue(false)
    live.registerBaseProperties()
    live.identify(
      "blocked-user",
      "google"
    )
    live.track(.signUp(method: .google))
    live.reset()
    #expect(calls.value == ["base", "identify:test-user:apple", "screen_view", "reset"])
  }

  @Test func firebaseScreenEventUsesGA4ScreenParameters() {
    let event = AnalyticsEvent.screenView(
      screen: .profile,
      referrer: nil
    )
    let parameters = AnalyticsUseCase.firebaseProperties(
      for: event,
      fallback: AnalyticsUseCase.eventProperties(event)
    )
    #expect(parameters["screen_name"] as? String == "profile")
    #expect(parameters["screen_class"] as? String == "profile")
    #expect(parameters["screen"] == nil)
  }

  @Test func eventNamesAreSnakeCase() {
    let events: [(AnalyticsEvent, String)] = [
      (.signUp(method: .apple), "sign_up"),
      (.screenView(screen: .login, referrer: nil), "screen_view"),
      (.uiAction(action: .flagSort, screen: .festivalFlag), "ui_action"),
      (.flagFollow(.init(flagID: "flag", isFollowing: true)), "flag_follow"),
      (.timetableAction(.init(action: .setOpen, festivalID: "fst")), "timetable_action"),
      (.packSync(.init(festivalID: "fst", result: .updated)), "pack_sync")
    ]

    for (event, name) in events {
      #expect(AnalyticsUseCase.eventName(event) == name)
    }
  }

  @Test func screenViewSendsReferrerOnlyWhenPresent() {
    let withoutReferrer = AnalyticsUseCase.eventProperties(.screenView(screen: .festivalList, referrer: nil))
    #expect(withoutReferrer.count == 1)
    #expect(withoutReferrer["screen"] as? String == "festival_list")

    let withReferrer = AnalyticsUseCase.eventProperties(.screenView(screen: .liveBoard, referrer: .festivalList))
    #expect(withReferrer["screen"] as? String == "live_board")
    #expect(withReferrer["referrer"] as? String == "festival_list")
  }

  @Test func eventPropertiesUseSnakeCaseKeys() {
    #expect(AnalyticsUseCase.eventProperties(.signUp(method: .google))["method"] as? String == "google")

    let uiAction = AnalyticsUseCase.eventProperties(.uiAction(action: .profileLogout, screen: .profile))
    #expect(uiAction["action"] as? String == "profile_logout")
    #expect(uiAction["screen"] as? String == "profile")

    let follow = AnalyticsUseCase.eventProperties(.flagFollow(.init(flagID: "flag", isFollowing: false)))
    #expect(follow.count == 1)
    #expect(follow["flag_id"] == nil)
    #expect(follow["is_following"] as? Bool == false)

    let timetable = AnalyticsUseCase.eventProperties(.timetableAction(.init(action: .scheduleToggle, festivalID: "fst")))
    #expect(timetable.count == 1)
    #expect(timetable["action"] as? String == "schedule_toggle")
    #expect(timetable["festival_id"] == nil)
    let setOpen = AnalyticsUseCase.eventProperties(.timetableAction(.init(action: .setOpen, festivalID: "fst", setID: "set")))
    #expect(setOpen.count == 1)
    #expect(setOpen["set_id"] == nil)

    let pack = AnalyticsUseCase.eventProperties(.packSync(.init(festivalID: "fst", result: .notModified)))
    #expect(pack.count == 1)
    #expect(pack["festival_id"] == nil)
    #expect(pack["result"] as? String == "not_modified")
  }

  @Test func rawValuesAreUniqueSnakeCase() {
    let names = AnalyticsScreen.allCases.map(\.rawValue) + AnalyticsButton.allCases.map(\.rawValue)
    #expect(Set(AnalyticsScreen.allCases.map(\.rawValue)).count == AnalyticsScreen.allCases.count)
    #expect(Set(AnalyticsButton.allCases.map(\.rawValue)).count == AnalyticsButton.allCases.count)
    #expect(names.allSatisfy { $0 == $0.lowercased() && !$0.contains(" ") })
  }

  @Test func baseSuperPropertiesCarryPlatformAndVersion() {
    let properties = AnalyticsUseCase.baseSuperProperties()
    #expect(Set(properties.keys) == ["os_type", "app_version", "build", "environment"])
    #expect(properties["os_type"] as? String == "ios")
  }

  @Test func unregisteredTestValueReportsIssues() {
    @Dependency(\.analyticsUseCase) var analyticsUseCase

    withKnownIssue {
      analyticsUseCase.identify("user", "apple")
    }
    withKnownIssue {
      analyticsUseCase.track(.screenView(screen: .login, referrer: nil))
    }
    withKnownIssue {
      analyticsUseCase.reset()
    }
    // 테스트 호스트 앱 시작 시 호출되므로 이슈를 남기지 않는다.
    analyticsUseCase.registerBaseProperties()
  }

  @Test func previewValueDoesNotReportIssues() {
    let analyticsUseCase = AnalyticsUseCase.previewValue
    analyticsUseCase.registerBaseProperties()
    analyticsUseCase.identify("user", nil)
    analyticsUseCase.track(.screenView(screen: .profile, referrer: nil))
    analyticsUseCase.reset()
  }
}
