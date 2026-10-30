import Foundation
import Testing
@testable import FestiCoreUtility

struct FestivalDateFormatTests {
  @Test func strictSeoulDayParsing() {
    #expect("2026-10-30".date(as: .day) != nil)
    #expect("2026.10.30".date(as: .day) == nil)
    #expect("2026-02-30".date(as: .day) == nil)
    #expect("2026-10-3".date(as: .day) == nil)
  }

  @Test func timeOutputUsesSeoulTimeZoneAnd24HourClock() throws {
    let date = try #require(ISO8601DateFormatter().date(from: "2026-10-30T03:05:00Z"))
    #expect(date.formatted(.time) == "12:05")
  }

  @Test func koreanFestivalDayUsesSeoulCalendar() throws {
    let date = try #require("2026-10-30".date(as: .day))
    #expect(date.formatted(.festivalDay) == "10/30(금)")
  }
}
