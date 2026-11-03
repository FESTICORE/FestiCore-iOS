//
//  TimetableEntityTests.swift
//  TimetableDomainTests
//
//  Created by FestiCore on 11/2/26.
//

import Foundation
import Testing
import TimetableDomainInterface

struct TimetableEntityTests {
  /// 2026-08-07 00:00 KST
  private let day = TimetableDay(
    id: "day-1",
    title: "8.7 금",
    date: Date(timeIntervalSince1970: 1_786_028_400),
    stages: [TimetableStage(id: "rivet", name: "리벳 스테이지")],
    sets: [
      TimetableSet(id: "lime", artist: "라임플래그스", stageID: "rivet", start: 1020, end: 1070, previousStart: 1000),
      TimetableSet(id: "midnight", artist: "미드나잇", stageID: "rivet", start: 1410, end: 1530),
    ]
  )

  @Test func timeTextsMatchDesign() {
    #expect(day.sets[1].timeRange == "23:30–다음날 01:30")
    #expect(TimetableSet(id: "a", artist: "", stageID: "", start: 750, end: 790).timeRange == "12:30–13:10")
    #expect(day.sets[0].timeRangeWithDuration == "17:00–17:50 · 50분")
    #expect(day.sets[0].previousTime == "16:40")
    #expect(day.sets[0].startChange == "20분 미뤄짐")
    #expect(TimetableSet(id: "b", artist: "", stageID: "", start: 1090, end: 1130, previousStart: 1105).startChange == "15분 당겨짐")
    #expect(day.sets[1].previousTime == nil)
    #expect(day.sets[1].startChange == nil)
    #expect(TimetableDay.clock(1530) == "01:30")
  }

  @Test func intervalAddsMinutesToDayStartAcrossMidnight() {
    let midnight = day.interval(of: day.sets[1])

    #expect(midnight.start == day.date.addingTimeInterval(1410 * 60))
    #expect(midnight.end == day.date.addingTimeInterval(1530 * 60))
    #expect(day.changedCount == 1)
  }

  @Test func statusFollowsCurrentTime() {
    let interval = day.interval(of: day.sets[0])

    #expect(TimetableSetDetail.Status(interval: interval, now: interval.start.addingTimeInterval(-90)) == .upcoming(minutes: 2))
    #expect(TimetableSetDetail.Status(interval: interval, now: interval.start) == .live)
    #expect(TimetableSetDetail.Status(interval: interval, now: interval.end) == .ended)
  }

  @Test func relativeTimeReadsHoursAndMinutes() {
    func text(_ status: TimetableSetDetail.Status) -> String {
      TimetableSetDetail(artist: "", stage: "", time: "", status: status, isScheduled: false).relativeTime
    }

    #expect(text(.upcoming(minutes: 40)) == "40분 후")
    #expect(text(.upcoming(minutes: 60)) == "1시간 후")
    #expect(text(.upcoming(minutes: 92)) == "1시간 32분 후")
    #expect(text(.live) == "공연 중")
    #expect(text(.ended) == "종료")
  }

  @Test func overlapMinutesAreTheSharedRange() {
    #expect(TimetableOverlap(start: 955, end: 990).minutes == 35)
  }

  @Test func overlapWarningUsesParticleForNonHangulName() {
    let overlap = TimetableSetOverlap(artist: "NELL", stage: "원더 스테이지", time: "15:55–16:45", minutes: 35)

    #expect(overlap.warning == "NELL(원더 스테이지 15:55–16:45)와 35분 겹쳐요")
  }

  @Test func overlapWarningUsesParticleForDecomposedHangulName() {
    let decomposed = "새벽 세션".decomposedStringWithCanonicalMapping
    let overlap = TimetableSetOverlap(artist: decomposed, stage: "리벳 스테이지", time: "00:30–01:30", minutes: 60)

    #expect(overlap.warning.hasSuffix(")과 60분 겹쳐요"))
  }
}
