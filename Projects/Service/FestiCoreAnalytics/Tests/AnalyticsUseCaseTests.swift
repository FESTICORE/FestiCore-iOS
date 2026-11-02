//
//  AnalyticsUseCaseTests.swift
//  FestiCoreAnalyticsTests
//
//  Created by FestiCore on 11/2/26.
//

import Dependencies
import FestiCoreAnalyticsInterface
import Testing
@testable import FestiCoreAnalytics

struct AnalyticsUseCaseTests {
  @Test func screenViewCarriesScreenName() {
    let event = AnalyticsEvent.screenView(.festivalList)

    #expect(event.name == "screen_view")
    #expect(event.properties == ["screen": "festival_list"])
    #expect(event.breadcrumbCategory == "navigation")
  }

  @Test func screenNamesAreUniqueSnakeCase() {
    let names = AnalyticsScreen.allCases.map(\.rawValue)

    #expect(Set(names).count == names.count)
    #expect(names.allSatisfy { $0 == $0.lowercased() && !$0.contains(" ") })
  }

  @Test func unregisteredTestDependencyReportsIssue() {
    @Dependency(\.analyticsUseCase) var analyticsUseCase

    withKnownIssue {
      analyticsUseCase.track(.screenView(.login))
    }
  }

  @Test func previewMockDoesNotReportIssue() {
    MockAnalyticsUseCase(reportsUnregisteredCall: false).track(.screenView(.profile))
  }

  @Test func injectedDependencyReceivesEvent() {
    let recorder = AnalyticsRecorder()

    withDependencies {
      $0.analyticsUseCase = recorder
    } operation: {
      @Dependency(\.analyticsUseCase) var analyticsUseCase
      analyticsUseCase.track(.screenView(.timetable))
    }

    #expect(recorder.events.value == [.screenView(.timetable)])
  }
}

private final class AnalyticsRecorder: AnalyticsUseCaseInterface {
  let events = LockIsolated<[AnalyticsEvent]>([])

  func track(_ event: AnalyticsEvent) {
    events.withValue { $0.append(event) }
  }
}
