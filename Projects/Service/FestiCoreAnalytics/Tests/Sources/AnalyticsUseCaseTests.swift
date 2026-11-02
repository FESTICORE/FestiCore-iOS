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
    #expect(follow["flag_id"] as? String == "flag")
    #expect(follow["is_following"] as? Bool == false)

    let timetable = AnalyticsUseCase.eventProperties(.timetableAction(.init(action: .scheduleToggle, festivalID: "fst")))
    #expect(timetable.count == 2)
    #expect(timetable["action"] as? String == "schedule_toggle")
    #expect(timetable["festival_id"] as? String == "fst")
    let setOpen = AnalyticsUseCase.eventProperties(.timetableAction(.init(action: .setOpen, festivalID: "fst", setID: "set")))
    #expect(setOpen["set_id"] as? String == "set")

    let pack = AnalyticsUseCase.eventProperties(.packSync(.init(festivalID: "fst", result: .notModified)))
    #expect(pack["festival_id"] as? String == "fst")
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
    #expect(Set(properties.keys) == ["os_type", "app_version", "build"])
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
