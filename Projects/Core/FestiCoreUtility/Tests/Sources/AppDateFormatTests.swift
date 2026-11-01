import Foundation
import Testing
@testable import FestiCoreUtility

struct AppDateFormatTests {
  @Test func strictSeoulDayParsing() {
    #expect("2026-10-30".date(as: .day) != nil)
    #expect("2026.10.30".date(as: .day) == nil)
    #expect("2026-02-30".date(as: .day) == nil)
    #expect("2026-10-3".date(as: .day) == nil)
  }

  @Test func timeOutputUsesSeoulTimeZoneAnd24HourClock() throws {
    let date = try #require("2026-10-30T03:05:00Z".isoDate)
    #expect(date.formatted(.time) == "12:05")
  }

  @Test func koreanDayFormatsUseSeoulCalendar() throws {
    let date = try #require("2026-10-30".date(as: .day))
    #expect(date.formatted(.festivalDay) == "10/30(금)")
    #expect(date.formatted(.liveBoardDay) == "10.30 (금)")
  }

  @Test func monthDayTimeUsesSeoulTimeZone() throws {
    let date = try #require("2026-10-30T15:05:00Z".isoDate)
    #expect(date.formatted(.monthDayTime) == "10/31 00:05")
  }

  @Test func isoParsingAcceptsFractionalAndWholeSeconds() {
    #expect("2026-10-30T12:00:00+09:00".isoDate != nil)
    #expect("2026-10-30T12:00:00.250+09:00".isoDate != nil)
    #expect("2026-10-30 12:00:00".isoDate == nil)
  }

  @Test func isoStringWritesSeoulOffsetWithMilliseconds() throws {
    let date = try #require("2026-10-30T03:05:00.123Z".isoDate)
    #expect(date.isoString == "2026-10-30T12:05:00.123+09:00")
  }
}
