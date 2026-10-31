import FestiCoreUtility
import FestivalDomainInterface
import Foundation
import Testing
@testable import Festival

struct FestivalListPresentationTests {
  @Test func searchAndBookedFilterUseActualCatalogFields() {
    let festivals = [
      festival(id: "one", name: "원더리벳", venue: "고양"),
      festival(id: "two", name: "펜타포트", venue: "인천")
    ]

    #expect(FestivalListPresentation.visible(
      festivals, query: "인천", bookedIDs: ["two"], onlyBooked: false
    ).map(\.id) == ["two"])
    #expect(FestivalListPresentation.visible(
      festivals, query: "", bookedIDs: ["one"], onlyBooked: true
    ).map(\.id) == ["one"])
    #expect(FestivalListPresentation.visible(
      festivals, query: "펜타", bookedIDs: ["one"], onlyBooked: true
    ).isEmpty)
  }

  @Test func dDayLiveAndEndedUseKoreanCalendarDays() {
    let festival = festival(
      id: "one", name: "공연", venue: nil,
      firstDate: "2026-10-30", lastDate: "2026-10-31"
    )

    #expect(FestivalListPresentation.timing(
      for: festival, now: utc("2026-10-27T15:00:00Z")
    ) == .daysUntil(2))
    #expect(FestivalListPresentation.timing(
      for: festival, now: utc("2026-10-30T00:00:00Z")
    ) == .live)
    #expect(FestivalListPresentation.timing(
      for: festival, now: utc("2026-10-31T15:00:00Z")
    ) == .ended)
  }

  @Test func listDateUsesKoreanDayAndRejectsInvalidServerDate() {
    #expect("2026-10-30".date(as: .day)?.formatted(.festivalDay) == "10/30(금)")
    #expect("2026-02-30".date(as: .day) == nil)
  }

  @Test func recentSearchesKeepNewestFirstWithoutDuplicates() {
    var storage = ""
    for keyword in ["펜타포트", "원더리벳", " 펜타포트 ", ""] {
      storage = FestivalListPresentation.recentSearchStorage(
        adding: keyword,
        to: storage
      )
    }

    #expect(FestivalListPresentation.recentSearches(from: storage) == ["펜타포트", "원더리벳"])
  }

  @Test func recentSearchesKeepOnlyTheLimit() {
    let storage = (1...12).reduce("") { storage, number in
      FestivalListPresentation.recentSearchStorage(
        adding: "검색\(number)",
        to: storage
      )
    }
    let searches = FestivalListPresentation.recentSearches(from: storage)

    #expect(searches.count == 10)
    #expect(searches.first == "검색12")
  }

  private func festival(
    id: String, name: String, venue: String?,
    firstDate: String? = nil, lastDate: String? = nil
  ) -> FestivalOverview {
    FestivalOverview(item: FestivalCatalogItem(
      id: id, name: name, venue: venue, firstDate: firstDate,
      lastDate: lastDate, packVersion: 1
    ), isCached: false)
  }

  private func utc(_ value: String) -> Date {
    ISO8601DateFormatter().date(from: value)!
  }
}
