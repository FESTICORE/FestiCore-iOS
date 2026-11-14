import FestivalDomainInterface
import Foundation
import Testing
@testable import FestiCoreLiveActivity

struct FestivalActivityDayStatusTests {
  @Test func beforeOpeningUsesTodayOpeningTime() throws {
    let status = FestivalActivityWidgetContent.dayStatus(
      state: Self.state(),
      snapshot: try Self.snapshot(),
      festivalID: "festival",
      now: try Self.date("2026-11-21T12:00:00+09:00"),
      calendar: Self.calendar
    )

    #expect(status == FestivalActivityWidgetContent.DayStatus(
      day: 1,
      phase: .beforeOpening(opensAt: try Self.date("2026-11-21T15:00:00+09:00"))
    ))
  }

  @Test func finishedDayPointsToTomorrowOpening() throws {
    let status = try #require(FestivalActivityWidgetContent.dayStatus(
      state: Self.state(),
      snapshot: try Self.snapshot(),
      festivalID: "festival",
      now: try Self.date("2026-11-21T23:30:00+09:00"),
      calendar: Self.calendar
    ))

    #expect(status.day == 1)
    #expect(status.isFinished)
    #expect(status.next?.day == 2)
    #expect(status.next?.isTomorrow == true)
    #expect(status.next?.opensAt == (try Self.date("2026-11-22T15:00:00+09:00")))
  }

  @Test func lastDayFinishedHasNoNextOpening() throws {
    let status = try #require(FestivalActivityWidgetContent.dayStatus(
      state: Self.state(),
      snapshot: try Self.snapshot(),
      festivalID: "festival",
      now: try Self.date("2026-11-22T23:30:00+09:00"),
      calendar: Self.calendar
    ))

    #expect(status.day == 2)
    #expect(status.isFinished)
    #expect(status.next == nil)
  }

  @Test func playingOrBetweenShowsHasNoDayStatus() throws {
    let playing = FestivalActivityWidgetContent.dayStatus(
      state: Self.state(nowStages: [
        .init(
          setId: "day1",
          stageId: "A",
          artist: "첫날 공연",
          startsAt: "2026-11-21T15:30:00+09:00",
          endsAt: "2026-11-21T23:00:00+09:00"
        )
      ]),
      snapshot: try Self.snapshot(),
      festivalID: "festival",
      now: try Self.date("2026-11-21T16:00:00+09:00"),
      calendar: Self.calendar
    )
    let betweenShows = FestivalActivityWidgetContent.dayStatus(
      state: Self.state(),
      snapshot: try Self.snapshot(),
      festivalID: "festival",
      now: try Self.date("2026-11-21T15:10:00+09:00"),
      calendar: Self.calendar
    )

    #expect(playing == nil)
    #expect(betweenShows == nil)
  }

  @Test func overnightShowFromPreviousDayIsStillPlaying() throws {
    let base = try Self.snapshot()
    let overnight = FestivalWidgetSnapshot.Performance(
      id: "overnight",
      artist: "새벽 공연",
      stageName: "메인",
      startsAt: try Self.date("2026-11-21T23:30:00+09:00"),
      endsAt: try Self.date("2026-11-22T01:00:00+09:00"),
      isSaved: false
    )
    let snapshot = FestivalWidgetSnapshot(
      festivalID: base.festivalID,
      festivalName: base.festivalName,
      firstDay: nil,
      lastDay: nil,
      updatedAt: base.updatedAt,
      hasPack: true,
      performances: base.performances + [overnight],
      days: base.days
    )

    let status = FestivalActivityWidgetContent.dayStatus(
      state: Self.state(),
      snapshot: snapshot,
      festivalID: "festival",
      now: try Self.date("2026-11-22T00:30:00+09:00"),
      calendar: Self.calendar
    )

    #expect(status == nil)
  }

  @Test func otherFestivalSnapshotHasNoDayStatus() throws {
    let status = FestivalActivityWidgetContent.dayStatus(
      state: Self.state(),
      snapshot: try Self.snapshot(),
      festivalID: "other",
      now: try Self.date("2026-11-21T12:00:00+09:00"),
      calendar: Self.calendar
    )

    #expect(status == nil)
  }
}

private extension FestivalActivityDayStatusTests {
  static var calendar: Calendar {
    var calendar = Calendar(identifier: .gregorian)
    calendar.timeZone = TimeZone(identifier: "Asia/Seoul") ?? .gmt
    return calendar
  }

  static func date(_ value: String) throws -> Date {
    return try #require(ISO8601DateFormatter().date(from: value))
  }

  static func state(
    nowStages: [FestiCoreFestivalActivityAttributes.ContentState.NowStage] = []
  ) -> FestiCoreFestivalActivityAttributes.ContentState {
    return FestiCoreFestivalActivityAttributes.ContentState(
      phase: .ongoing,
      startDate: Date(timeIntervalSince1970: 0),
      nowStages: nowStages
    )
  }

  static func snapshot() throws -> FestivalWidgetSnapshot {
    return FestivalWidgetSnapshot(
      festivalID: "festival",
      festivalName: "축제",
      firstDay: nil,
      lastDay: nil,
      updatedAt: try date("2026-11-21T09:00:00+09:00"),
      hasPack: true,
      performances: [
        .init(
          id: "day1",
          artist: "첫날 공연",
          stageName: "메인",
          startsAt: try date("2026-11-21T15:30:00+09:00"),
          endsAt: try date("2026-11-21T23:00:00+09:00"),
          isSaved: true
        ),
        .init(
          id: "day2",
          artist: "둘째 날 공연",
          stageName: "메인",
          startsAt: try date("2026-11-22T16:10:00+09:00"),
          endsAt: try date("2026-11-22T23:00:00+09:00"),
          isSaved: true
        ),
      ],
      days: [
        .init(
          date: try date("2026-11-21T00:00:00+09:00"),
          opensAt: try date("2026-11-21T15:00:00+09:00")
        ),
        .init(
          date: try date("2026-11-22T00:00:00+09:00"),
          opensAt: try date("2026-11-22T15:00:00+09:00")
        ),
      ]
    )
  }
}
