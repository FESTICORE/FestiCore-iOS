import FestivalDomainInterface
import Foundation
import Testing
@testable import FestiCoreLiveActivity

/// Figma Widget·Live Activity 종료 1시간 전 `마지막 셔틀  정문 23:40 · 막차 23:52` 판정.
struct FestivalActivityHomeRideTests {
  @Test func shuttleAndTrainTodayShowStopAndBothTimes() throws {
    let ride = try #require(FestivalActivityWidgetContent.homeRide(
      snapshot: try Self.snapshot(),
      festivalID: "festival",
      now: try Self.date("2026-11-21T22:58:00+09:00"),
      calendar: Self.calendar
    ))

    #expect(ride.label == "마지막 셔틀")
    #expect(ride.detail == "정문 23:40 · 막차 23:52")
    #expect(ride.target == (try Self.date("2026-11-21T23:40:00+09:00")))
    #expect(ride.trainStationName == "킨텍스역")
    // Figma Widget Small Bar `셔틀 23:40`, Lock Screen 사각형 `정문 · 막차 23:52`
    #expect(ride.shortText == "셔틀 23:40")
    #expect(ride.accessoryDetail == "정문 · 막차 23:52")
  }

  @Test func trainAfterMidnightStillShows() throws {
    let ride = try #require(FestivalActivityWidgetContent.homeRide(
      snapshot: try Self.snapshot(
        lastShuttleAt: "2026-11-21T23:40:00+09:00",
        lastTrainAt: "2026-11-22T00:20:00+09:00"
      ),
      festivalID: "festival",
      now: try Self.date("2026-11-21T23:45:00+09:00"),
      calendar: Self.calendar
    ))

    #expect(ride.label == "막차")
    #expect(ride.detail == "00:20 킨텍스역")
    #expect(ride.shortText == "막차 00:20")
    #expect(ride.target == (try Self.date("2026-11-22T00:20:00+09:00")))
  }

  @Test func departedShuttleLeavesTrainWithStation() throws {
    let ride = try #require(FestivalActivityWidgetContent.homeRide(
      snapshot: try Self.snapshot(),
      festivalID: "festival",
      now: try Self.date("2026-11-21T23:45:00+09:00"),
      calendar: Self.calendar
    ))

    #expect(ride.shuttleAt == nil)
    #expect(ride.label == "막차")
    #expect(ride.detail == "23:52 킨텍스역")
    #expect(ride.shortText == "막차 23:52")
    #expect(ride.accessoryDetail == "23:52 킨텍스역")
    #expect(ride.target == (try Self.date("2026-11-21T23:52:00+09:00")))
  }

  @Test func missingStopAndStationShowTimesOnly() throws {
    let ride = try #require(FestivalActivityWidgetContent.homeRide(
      snapshot: try Self.snapshot(
        shuttleStopName: " ",
        trainStationName: nil
      ),
      festivalID: "festival",
      now: try Self.date("2026-11-21T22:58:00+09:00"),
      calendar: Self.calendar
    ))

    #expect(ride.detail == "23:40 · 막차 23:52")
    #expect(ride.accessoryDetail == "막차 23:52")
  }

  @Test func departedOrOtherDayOrOtherFestivalHasNoRide() throws {
    let snapshot = try Self.snapshot()
    // 둘 다 떠났다.
    #expect(FestivalActivityWidgetContent.homeRide(
      snapshot: snapshot,
      festivalID: "festival",
      now: try Self.date("2026-11-21T23:55:00+09:00"),
      calendar: Self.calendar
    ) == nil)
    // 12시간보다 먼 다음 날 시각은 전날 안내로 보이지 않는다.
    #expect(FestivalActivityWidgetContent.homeRide(
      snapshot: snapshot,
      festivalID: "festival",
      now: try Self.date("2026-11-20T22:58:00+09:00"),
      calendar: Self.calendar
    ) == nil)
    #expect(FestivalActivityWidgetContent.homeRide(
      snapshot: snapshot,
      festivalID: "other",
      now: try Self.date("2026-11-21T22:58:00+09:00"),
      calendar: Self.calendar
    ) == nil)
    #expect(FestivalActivityWidgetContent.homeRide(
      snapshot: try Self.snapshot(
        lastShuttleAt: nil,
        lastTrainAt: nil
      ),
      festivalID: "festival",
      now: try Self.date("2026-11-21T22:58:00+09:00"),
      calendar: Self.calendar
    ) == nil)
  }
}

private extension FestivalActivityHomeRideTests {
  static var calendar: Calendar {
    var calendar = Calendar(identifier: .gregorian)
    calendar.timeZone = TimeZone(identifier: "Asia/Seoul") ?? .gmt
    return calendar
  }

  static func date(_ value: String) throws -> Date {
    return try #require(ISO8601DateFormatter().date(from: value))
  }

  static func snapshot(
    lastShuttleAt: String? = "2026-11-21T23:40:00+09:00",
    shuttleStopName: String? = "정문",
    lastTrainAt: String? = "2026-11-21T23:52:00+09:00",
    trainStationName: String? = "킨텍스역"
  ) throws -> FestivalWidgetSnapshot {
    return FestivalWidgetSnapshot(
      festivalID: "festival",
      festivalName: "축제",
      firstDay: nil,
      lastDay: nil,
      updatedAt: try date("2026-11-21T09:00:00+09:00"),
      hasPack: true,
      performances: [],
      lastShuttleAt: try lastShuttleAt.map(date),
      shuttleStopName: shuttleStopName,
      lastTrainAt: try lastTrainAt.map(date),
      trainStationName: trainStationName
    )
  }
}
