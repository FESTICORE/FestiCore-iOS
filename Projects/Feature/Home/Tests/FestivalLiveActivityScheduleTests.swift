import FestivalDomainInterface
import FestiCorePackInterface
import Foundation
import Testing
@testable import Home

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

  @Test func packOnlyOverviewUsesChronologicalValidDays() throws {
    let pack = CachedFestivalPack(
      festivalID: "fst_1", packVersion: 1, etag: "\"v1\"",
      pack: Data(#"{"id":"fst_1","days":[{"date":"2026-10-31"},{"date":"invalid"},{"date":"2026-10-29"},{"date":"2026-10-30"}]}"#.utf8)
    )
    let overview = try #require(FestivalOverview(pack: pack))

    #expect(overview.firstDate == "2026-10-29")
    #expect(overview.lastDate == "2026-10-31")
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

  private func overview(first: String?, last: String?) -> FestivalOverview {
    FestivalOverview(item: FestivalCatalogItem(
      id: "fst_1", name: "축제", firstDate: first, lastDate: last, packVersion: 1
    ), isCached: false)
  }

  private func utc(_ value: String) -> Date {
    ISO8601DateFormatter().date(from: value)!
  }
}
