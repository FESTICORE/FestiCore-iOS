import FestivalDomainInterface
import FestiCorePackInterface
import Foundation
import Testing
@testable import Festival

struct FestivalLiveActivityScheduleTests {
  @Test func dateOnlyUsesSeoulDayBoundaries() throws {
    let festival = overview(first: "2026-10-29", last: "2026-10-30")
    let now = utc("2026-10-28T13:00:00Z")
    let schedule = try #require(FestivalLiveActivitySchedule.resolve(
      festival: festival, pack: nil, now: now
    ))

    #expect(schedule.startDate == utc("2026-10-28T15:00:00Z"))
    #expect(schedule.endDate == utc("2026-10-30T15:00:00Z"))
    #expect(schedule.phase == .upcoming)
    #expect(schedule.canStart)
    #expect(schedule.nextBoundary == schedule.startDate)
  }

  @Test func overnightDayEndExtendsCalendarBoundary() throws {
    let pack = try JSONDecoder().decode(FestivalPackDocument.self, from: Data(
      #"{"id":"fst_1","days":[{"date":"2026-11-20","endsAt":"2026-11-21T02:00:00+09:00"}]}"#.utf8
    ))
    let festival = overview(first: "2026-11-20", last: "2026-11-20")
    let end = utc("2026-11-20T17:00:00Z")
    let ongoing = try #require(FestivalLiveActivitySchedule.resolve(
      festival: festival, pack: pack, now: end.addingTimeInterval(-1)
    ))
    #expect(ongoing.endDate == end)
    #expect(ongoing.phase == .ongoing)
    #expect(ongoing.canStart)
    #expect(ongoing.nextBoundary == end)
    let finished = try #require(FestivalLiveActivitySchedule.resolve(
      festival: festival, pack: pack, now: end
    ))
    #expect(finished.phase == .finished)
    #expect(!finished.canStart)
    #expect(finished.nextBoundary == nil)
  }

  @Test func earlierOrInvalidDayEndsCannotShortenCalendarBoundary() throws {
    let pack = try JSONDecoder().decode(FestivalPackDocument.self, from: Data(
      #"{"id":"fst_1","days":[{"date":"2026-11-20","endsAt":"2026-11-20T23:00:00+09:00"},{"date":"2026-11-20","endsAt":"2026-11-21T25:00:00+09:00"}]}"#.utf8
    ))
    let schedule = try #require(FestivalLiveActivitySchedule.resolve(
      festival: overview(first: "2026-11-20", last: "2026-11-20"),
      pack: pack, now: utc("2026-11-20T14:30:00Z")
    ))
    #expect(schedule.endDate == utc("2026-11-20T15:00:00Z"))
    #expect(schedule.phase == .ongoing)
  }

  @Test func timestampKeepsItsExplicitOffset() throws {
    let festival = overview(
      first: "2026-10-29T12:30:00+09:00", last: "2026-10-29T16:00:00+09:00"
    )
    let schedule = try #require(FestivalLiveActivitySchedule.resolve(
      festival: festival, pack: nil, now: utc("2026-10-29T04:00:00Z")
    ))

    #expect(schedule.startDate == utc("2026-10-29T03:30:00Z"))
    #expect(schedule.endDate == utc("2026-10-29T07:00:00Z"))
    #expect(schedule.phase == .ongoing)
    #expect(schedule.nextBoundary == schedule.endDate)
  }

  @Test func startEligibilityAndEndAreExactBoundaries() throws {
    let festival = overview(first: "2026-10-29", last: "2026-10-29")
    let eligibility = utc("2026-10-28T13:00:00Z")

    let before = try #require(FestivalLiveActivitySchedule.resolve(
      festival: festival, pack: nil, now: eligibility.addingTimeInterval(-1)
    ))
    #expect(!before.canStart)
    #expect(before.nextBoundary == eligibility)

    let atEligibility = try #require(FestivalLiveActivitySchedule.resolve(
      festival: festival, pack: nil, now: eligibility
    ))
    #expect(atEligibility.canStart)
    #expect(atEligibility.phase == .upcoming)

    let atEnd = try #require(FestivalLiveActivitySchedule.resolve(
      festival: festival, pack: nil, now: utc("2026-10-29T15:00:00Z")
    ))
    #expect(!atEnd.canStart)
    #expect(atEnd.phase == .finished)
    #expect(atEnd.nextBoundary == nil)
  }

  @Test func missingCatalogFieldsFallbackIndependentlyToUnsortedPackDays() throws {
    let festival = overview(first: nil, last: "2026-11-01")
    let pack = try JSONDecoder().decode(
      FestivalPackDocument.self,
      from: Data(#"{"id":"fst_1","days":[{"date":"invalid"},{"date":"2026-10-31"},{"date":"2026-10-29"},{"date":"2026-10-30"}]}"#.utf8)
    )
    let schedule = try #require(FestivalLiveActivitySchedule.resolve(
      festival: festival, pack: pack, now: utc("2026-10-29T00:00:00Z")
    ))

    #expect(schedule.startDate == utc("2026-10-28T15:00:00Z"))
    #expect(schedule.endDate == utc("2026-11-01T15:00:00Z"))
    #expect(schedule.phase == .ongoing)
  }

  @Test func malformedCatalogDateDoesNotSilentlyUseCachedPack() throws {
    let pack = try JSONDecoder().decode(
      FestivalPackDocument.self,
      from: Data(#"{"id":"fst_1","days":[{"date":"2026-10-29"}]}"#.utf8)
    )
    #expect(FestivalLiveActivitySchedule.resolve(
      festival: overview(first: "2026-02-30", last: "2026-10-30"),
      pack: pack, now: utc("2026-10-29T00:00:00Z")
    ) == nil)
  }

  @Test func timetableWithoutDaysSuppliesFestivalDates() throws {
    let pack = try JSONDecoder().decode(
      FestivalPackDocument.self,
      from: Data(#"{"id":"fst_1","timetable":[{"id":"set_2","startsAt":"2026-10-30T21:00:00+09:00","endsAt":"2026-10-31T00:30:00+09:00"},{"id":"set_1","startsAt":"2026-10-29T12:00:00+09:00"}]}"#.utf8)
    )
    let schedule = try #require(FestivalLiveActivitySchedule.resolve(
      festival: overview(first: nil, last: nil), pack: pack,
      now: utc("2026-10-29T03:00:00Z")
    ))

    #expect(schedule.startDate == utc("2026-10-28T15:00:00Z"))
    #expect(schedule.endDate == utc("2026-10-31T15:00:00Z"))
    #expect(schedule.phase == .ongoing)
    #expect(schedule.canStart)
  }

  @Test func packOnlyOverviewUsesChronologicalValidDays() throws {
    let pack = CachedFestivalPack(
      festivalID: "fst_1", packVersion: 1, etag: "\"v1\"",
      pack: Data(#"{"id":"fst_1","days":[{"date":"2026-10-31"},{"date":"invalid"},{"date":"2026-10-29"},{"date":"2026-10-30"}]}"#.utf8)
    )
    let overview = try #require(FestivalOverview(pack: pack))

    #expect(overview.firstDate == "2026-10-29")
    #expect(overview.lastDate == "2026-10-31")
  }

  @Test func metadataOnlyOverviewKeepsEventPeriodAndArtistsWithoutPerformances() throws {
    let pack = CachedFestivalPack(
      festivalID: "fst_1", packVersion: 1, etag: "v1",
      pack: Data(#"{"id":"fst_1","eventPeriod":{"firstDate":"2026-10-29","lastDate":"2026-10-31"},"days":[],"stages":[],"sets":[],"artists":[{"name":"Artist"}]}"#.utf8)
    )
    let overview = try #require(FestivalOverview(pack: pack))
    #expect(overview.firstDate == "2026-10-29")
    #expect(overview.lastDate == "2026-10-31")
    #expect(overview.artists?.first?.name == "Artist")
    #expect(overview.artists?.first?.performances.isEmpty == true)
    let document = try JSONDecoder().decode(FestivalPackDocument.self, from: pack.pack)
    #expect(FestivalLiveActivitySchedule.resolve(
      festival: overview, pack: document, now: utc("2026-10-29T00:00:00Z")
    ) == nil)
  }

  @Test func eventPeriodWithPublishedPerformancesKeepsLiveActivityAvailable() throws {
    let pack = try JSONDecoder().decode(FestivalPackDocument.self, from: Data(#"{"id":"fst_1","eventPeriod":{"firstDate":"2026-10-29","lastDate":"2026-10-29"},"days":[{"date":"2026-10-29"}],"sets":[{"id":"set_1","artist":"Artist","startsAt":"2026-10-29T12:00:00+09:00","endsAt":"2026-10-29T13:00:00+09:00"}]}"#.utf8))
    #expect(FestivalLiveActivitySchedule.resolve(
      festival: overview(first: "2026-10-29", last: "2026-10-29"),
      pack: pack, now: utc("2026-10-29T00:00:00Z")
    ) != nil)
  }

  @Test func singleDayEventPeriodRemainsValidOffline() throws {
    let pack = CachedFestivalPack(
      festivalID: "fst_1", packVersion: 1, etag: "v1",
      pack: Data(#"{"id":"fst_1","eventPeriod":{"firstDate":"2026-10-29","lastDate":"2026-10-29"}}"#.utf8)
    )
    let overview = try #require(FestivalOverview(pack: pack))
    #expect(overview.firstDate == "2026-10-29")
    #expect(overview.lastDate == "2026-10-29")
  }

  @Test func invalidEventPeriodsDoNotBecomeOfflineDates() throws {
    for (first, last) in [
      ("2026-02-30", "2026-03-01"), ("2026-10-31", "2026-10-29"),
      ("2026-1-1", "2026-01-02"), ("2026-10-29", "invalid")
    ] {
      let pack = CachedFestivalPack(
        festivalID: "fst_1", packVersion: 1, etag: "v1",
        pack: Data("{\"id\":\"fst_1\",\"days\":[],\"eventPeriod\":{\"firstDate\":\"\(first)\",\"lastDate\":\"\(last)\"}}".utf8)
      )
      let overview = try #require(FestivalOverview(pack: pack))
      #expect(overview.firstDate == nil)
      #expect(overview.lastDate == nil)
    }
  }

  @Test func scheduledDaysTakePriorityOverEventPeriod() throws {
    let pack = CachedFestivalPack(
      festivalID: "fst_1", packVersion: 1, etag: "v1",
      pack: Data(#"{"id":"fst_1","days":[{"date":"2026-10-30"}],"eventPeriod":{"firstDate":"2026-10-29","lastDate":"2026-10-31"}}"#.utf8)
    )
    let overview = try #require(FestivalOverview(pack: pack))
    #expect(overview.firstDate == "2026-10-30")
    #expect(overview.lastDate == "2026-10-30")
  }

  @Test func invalidAndIncompleteDatesCannotProduceSchedule() throws {
    let invalid = ["2026-02-30", "2026-10-29T25:00:00+09:00", "2026-10-29T12:00:00", "2026-10-29T12:00:00+09:99"]
    for value in invalid {
      #expect(FestivalLiveActivitySchedule.resolve(
        festival: overview(first: value, last: "2026-10-30"), pack: nil, now: .now
      ) == nil)
    }
    #expect(FestivalLiveActivitySchedule.resolve(
      festival: overview(first: "2026-10-30", last: "2026-10-29"), pack: nil, now: .now
    ) == nil)
  }

  @Test func nextSavedPerformanceIgnoresUnsavedAndPastSets() throws {
    let pack = try JSONDecoder().decode(FestivalPackDocument.self, from: Data(
      #"{"id":"fst_1","sets":[{"id":"past","startsAt":"2026-10-29T08:00:00Z"},{"id":"later","startsAt":"2026-10-29T12:00:00Z"},{"id":"first","startsAt":"2026-10-29T10:00:00Z"},{"id":"other","startsAt":"2026-10-29T09:00:00Z"}]}"#.utf8
    ))
    let now = utc("2026-10-29T09:30:00Z")

    #expect(FestivalLiveActivitySchedule.nextSavedPerformanceStart(
      pack: pack, setIDs: ["past", "later", "first"], now: now
    ) == utc("2026-10-29T10:00:00Z"))
    #expect(FestivalLiveActivitySchedule.nextSavedPerformanceStart(
      pack: pack, setIDs: ["past"], now: now
    ) == nil)
  }

  private func overview(first: String?, last: String?) -> FestivalOverview {
    return FestivalOverview(item: FestivalCatalogItem(
      id: "fst_1", name: "축제", firstDate: first, lastDate: last, packVersion: 1
    ), isCached: false)
  }

  private func utc(_ value: String) -> Date {
    return ISO8601DateFormatter().date(from: value)!
  }
}
