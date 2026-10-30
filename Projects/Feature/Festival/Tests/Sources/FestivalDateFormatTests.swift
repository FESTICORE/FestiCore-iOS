import Foundation
import Testing
@testable import Festival

struct FestivalDateFormatTests {
  @Test func strictSeoulDayParsing() {
    #expect(FestivalDateFormat.day(from: "2026-10-30") != nil)
    #expect(FestivalDateFormat.day(from: "2026.10.30") == nil)
    #expect(FestivalDateFormat.day(from: "2026-02-30") == nil)
    #expect(FestivalDateFormat.day(from: "2026-10-3") == nil)
  }

  @Test func timeOutputUsesSeoulTimeZoneAnd24HourClock() throws {
    let date = try #require(ISO8601DateFormatter().date(from: "2026-10-30T03:05:00Z"))
    #expect(FestivalDateFormat.time(from: date) == "12:05")
  }
}
