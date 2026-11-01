import FestiCoreUtility
import FestiCorePackInterface
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

  @Test func cardStatusFollowsFigmaPrecedenceAndRedThreshold() {
    let now = utc("2026-11-01T03:00:00Z")
    #expect(FestivalListPresentation.cardStatus(for: festival(id: "d3", firstDate: "2026-11-04"), now: now) == .closing("D-3"))
    #expect(FestivalListPresentation.cardStatus(for: festival(id: "d4", firstDate: "2026-11-05"), now: now) == .dDay("D-4"))
    #expect(FestivalListPresentation.cardStatus(for: festival(id: "live", firstDate: "2026-11-01"), now: now) == .dDay("진행 중"))
    #expect(FestivalListPresentation.cardStatus(for: festival(id: "none"), now: now) == .dDay("일정 확인"))
    #expect(FestivalListPresentation.cardStatus(
      for: festival(id: "soon", firstDate: "2026-11-02", status: "discovered"), now: now
    ) == .upcoming)
    #expect(FestivalListPresentation.cardStatus(
      for: festival(id: "v0", firstDate: "2026-11-02", packVersion: 0), now: now
    ) == .upcoming)
    #expect(FestivalListPresentation.cardStatus(
      for: festival(id: "end", firstDate: "2026-10-01", lastDate: "2026-10-02", status: "discovered"), now: now
    ) == .ended)
  }

  @Test func packCopyDependsOnTimingBookingAndCachedVersion() {
    let now = utc("2026-11-01T03:00:00Z")
    func copy(_ festival: FestivalOverview, booked: Bool = true, onlyBooked: Bool = false) -> FestivalListPresentation.PackCopy {
      FestivalListPresentation.packCopy(for: festival, isBooked: booked, onlyBooked: onlyBooked, now: now)
    }
    #expect(copy(festival(id: "end", firstDate: "2026-10-01")) == .unavailable("종료된 페스티벌이라 팩을 받을 수 없어요"))
    let discovered = festival(id: "soon", firstDate: "2026-11-20", status: "discovered")
    #expect(copy(discovered) == .unavailable("티켓 오픈 후 등록하고 팩을 받을 수 있어요"))
    #expect(copy(discovered, onlyBooked: true) == .unavailable("티켓이 열리면 팩을 받을 수 있어요"))
    #expect(copy(festival(id: "free", firstDate: "2026-11-20"), booked: false)
      == .unavailable("예매한 페스티벌로 등록하면 팩을 받을 수 있어요"))
    #expect(copy(festival(id: "new", firstDate: "2026-11-20")) == .ready("팩 받기"))
    #expect(copy(festival(id: "same", firstDate: "2026-11-20", packVersion: 2, cachedPackVersion: 2))
      == .received("팩 받음 · 최신 버전"))
    #expect(copy(festival(id: "newer", firstDate: "2026-11-20", packVersion: 2, cachedPackVersion: 3))
      == .received("팩 받음 · 최신 버전"))
    #expect(copy(festival(id: "stale", firstDate: "2026-11-20", packVersion: 3, cachedPackVersion: 2))
      == .ready("팩 업데이트"))
  }

  @Test func sortedPutsLiveThenNearestThenOpeningSoonThenRecentlyEnded() {
    let now = utc("2026-11-01T03:00:00Z")
    let festivals = [
      festival(id: "endedOld", firstDate: "2026-10-01", lastDate: "2026-10-02"),
      festival(id: "far", firstDate: "2026-12-01"),
      festival(id: "soon", firstDate: "2026-11-03", status: "discovered"),
      festival(id: "endedNew", firstDate: "2026-10-20", lastDate: "2026-10-21"),
      festival(id: "near", firstDate: "2026-11-05"),
      festival(id: "live", firstDate: "2026-10-31", lastDate: "2026-11-02"),
      festival(id: "undated")
    ]

    #expect(FestivalListPresentation.sorted(festivals, now: now).map(\.id)
      == ["live", "near", "far", "soon", "undated", "endedNew", "endedOld"])
  }

  @Test func packOnlyRowUsesFirstHttpsTicketLinkFromPack() throws {
    let pack = CachedFestivalPack(
      festivalID: "fst_1", packVersion: 2, etag: "\"v2\"",
      pack: Data(#"{"id":"fst_1","packVersion":2,"ticketLinks":[null,{"label":1,"url":"https://x.com"},{"label":"구","url":"http://old.com"},{"label":"멜론","url":"https://ticket.melon.com/a"}]}"#.utf8)
    )
    let overview = try #require(FestivalOverview(pack: pack))

    #expect(overview.ticketURL == URL(string: "https://ticket.melon.com/a"))
    #expect(overview.cachedPackVersion == 2)
    #expect(overview.catalogStatus == nil)
  }

  private func festival(
    id: String, name: String? = nil, venue: String? = nil,
    firstDate: String? = nil, lastDate: String? = nil,
    status: String? = nil, packVersion: Int = 1, cachedPackVersion: Int? = nil
  ) -> FestivalOverview {
    FestivalOverview(item: FestivalCatalogItem(
      id: id, name: name ?? id, venue: venue, firstDate: firstDate,
      lastDate: lastDate, packVersion: packVersion, status: status
    ), isCached: cachedPackVersion != nil, cachedPackVersion: cachedPackVersion)
  }

  private func utc(_ value: String) -> Date {
    ISO8601DateFormatter().date(from: value)!
  }
}
