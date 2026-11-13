import ComposableArchitecture
import FestiCoreAnalyticsInterface
import FestiCoreUtility
import FestiCorePackInterface
import FestivalDomainInterface
import Foundation
import Testing
@testable import Festival

struct FestivalListPresentationTests {
  @Test @MainActor func listAppearanceTracksScreenView() async {
    let analytics = LockIsolated<[AnalyticsEvent]>([])
    let store = TestStore(initialState: FestivalFeature.State()) {
      FestivalFeature()
    } withDependencies: {
      $0.analyticsUseCase.track = { event in analytics.withValue { $0.append(event) } }
    }

    await store.send(.view(.festivalListOnAppear))
    #expect(analytics.value == [.screenView(
      screen: .festivalList,
      referrer: nil
    )])
  }

  @Test func searchAndBookedFilterUseActualCatalogFields() {
    let festivals = [
      festival(
        id: "one",
        name: "원더리벳",
        venue: "고양"
      ),
      festival(
        id: "two",
        name: "펜타포트",
        venue: "인천"
      )
    ]

    #expect(FestivalListPresentation.visible(
      festivals,
      query: "인천",
      bookedIDs: ["two"],
      onlyBooked: false
    ).map(\.id) == ["two"])
    #expect(FestivalListPresentation.visible(
      festivals,
      query: "",
      bookedIDs: ["one"],
      onlyBooked: true
    ).map(\.id) == ["one"])
    #expect(FestivalListPresentation.visible(
      festivals,
      query: "펜타",
      bookedIDs: ["one"],
      onlyBooked: true
    ).isEmpty)
  }

  @Test func searchMatchesCaseDiacriticsAndFullWidthCharacters() {
    let festivals = [festival(
      id: "one",
      name: "Ｃａｆé Festival",
      venue: "서울"
    )]
    #expect(FestivalListPresentation.visible(
      festivals,
      query: "cafe",
      bookedIDs: [],
      onlyBooked: false
    ).map(\.id) == ["one"])
    #expect(FestivalListPresentation.visible(
      festivals,
      query: "ＣＡＦＥ",
      bookedIDs: [],
      onlyBooked: false
    ).map(\.id) == ["one"])
  }

  @Test func artistSearchUsesServerProjectionAndKeepsFestivalResultSeparate() {
    let item = FestivalCatalogItem(
      id: "one",
      name: "원더리벳",
      venue: "고양",
      packVersion: 1,
      artists: [FestivalCatalogArtist(
        name: "삼보마스터",
        performances: [
        FestivalCatalogPerformance(
          startsAt: "2026-11-21T09:00:00Z",
          date: "2026-11-21",
          stageName: "리벳 스테이지"
        )
      ]
      )]
    )
    let festival = FestivalOverview(
      item: item,
      isCached: false
    )

    #expect(FestivalListPresentation.visible(
      [festival],
      query: "삼보",
      bookedIDs: [],
      onlyBooked: false
    ).isEmpty)
    let matches = FestivalListPresentation.matchingArtists(
      [festival],
      query: "삼보"
    )
    #expect(matches.map(\.artist.name) == ["삼보마스터"])
    #expect(matches.map(\.festival.id) == ["one"])
    #expect(FestivalListPresentation.artistMeta(
      matches[0],
      now: utc("2026-11-01T03:00:00Z")
    )
      == "원더리벳 · 11/21(토) 리벳 스테이지")
    #expect(FestivalListPresentation.matchingArtists(
      [festival],
      query: " "
    ).isEmpty)
    #expect(FestivalOverview(
      item: FestivalCatalogItem(
      id: "old",
      name: "옛 데이터",
      packVersion: 1
    ),
      isCached: false
    ).artists == nil)
  }

  @Test func dDayLiveAndEndedUseKoreanCalendarDays() {
    let festival = festival(
      id: "one",
      name: "공연",
      venue: nil,
      firstDate: "2026-10-30",
      lastDate: "2026-10-31"
    )

    #expect(FestivalListPresentation.timing(
      for: festival,
      now: utc("2026-10-27T15:00:00Z")
    ) == .daysUntil(2))
    #expect(FestivalListPresentation.timing(
      for: festival,
      now: utc("2026-10-30T00:00:00Z")
    ) == .live)
    #expect(FestivalListPresentation.timing(
      for: festival,
      now: utc("2026-10-31T15:00:00Z")
    ) == .ended)
  }

  @Test func listDateUsesKoreanDayAndRejectsInvalidServerDate() {
    #expect("2026-10-30".date(as: .day)?.formatted(.festivalDay) == "10/30(금)")
    #expect("2026-02-30".date(as: .day) == nil)
  }

  @Test func cardStatusFollowsFigmaPrecedenceAndRedThreshold() {
    let now = utc("2026-11-01T03:00:00Z")
    #expect(FestivalListPresentation.cardStatus(
      for: festival(
      id: "d3",
      firstDate: "2026-11-04"
    ),
      now: now
    ) == .closing("D-3"))
    #expect(FestivalListPresentation.cardStatus(
      for: festival(
      id: "d4",
      firstDate: "2026-11-05"
    ),
      now: now
    ) == .dDay("D-4"))
    #expect(FestivalListPresentation.cardStatus(
      for: festival(
      id: "live",
      firstDate: "2026-11-01"
    ),
      now: now
    ) == .dDay("진행 중"))
    #expect(FestivalListPresentation.cardStatus(
      for: festival(id: "none"),
      now: now
    ) == .dDay("일정 확인"))
    #expect(FestivalListPresentation.cardStatus(
      for: festival(
        id: "soon",
        firstDate: "2026-11-02",
        status: "discovered"
      ),
      now: now
    ) == .closing("D-1"))
    #expect(FestivalListPresentation.cardStatus(
      for: festival(
        id: "v0",
        firstDate: "2026-11-02",
        packVersion: 0
      ),
      now: now
    ) == .upcoming)
    #expect(FestivalListPresentation.cardStatus(
      for: festival(
        id: "end",
        firstDate: "2026-10-01",
        lastDate: "2026-10-02",
        status: "discovered"
      ),
      now: now
    ) == .ended)
    #expect(FestivalListPresentation.searchBadge(
      for: festival(
        id: "soon",
        firstDate: "2026-11-02",
        status: "discovered"
      ),
      now: now
    ) == "D-1")
    #expect(FestivalListPresentation.searchBadge(
      for: festival(
        id: "end",
        firstDate: "2026-10-01",
        lastDate: "2026-10-02"
      ),
      now: now
    ) == nil)
  }

  @Test func pastLastDateEndsFestivalEvenWithoutValidFirstDate() {
    let now = utc("2026-11-01T03:00:00Z")
    #expect(FestivalListPresentation.timing(
      for: festival(
      id: "a",
      lastDate: "2026-10-02"
    ),
      now: now
    ) == .ended)
    #expect(FestivalListPresentation.timing(
      for: festival(
        id: "b",
        firstDate: "2026-02-30",
        lastDate: "2026-10-02"
      ),
      now: now
    ) == .ended)
    #expect(FestivalListPresentation.timing(
      for: festival(
      id: "c",
      lastDate: "2026-12-02"
    ),
      now: now
    ) == .undated)
  }

  @Test func endedOrderFallsBackToFirstDateWhenLastDateIsInvalid() {
    let now = utc("2026-11-10T03:00:00Z")
    let festivals = [
      festival(
        id: "early",
        firstDate: "2026-10-01",
        lastDate: "2026-10-02"
      ),
      festival(
        id: "lateInvalidEnd",
        firstDate: "2026-10-31",
        lastDate: "2026-02-30"
      )
    ]

    #expect(FestivalListPresentation.sorted(
      festivals,
      now: now
    ).map(\.id) == ["lateInvalidEnd", "early"])
  }

  @Test func packCopyPreservesReceivedPacksAndAllowsPublishedEndedDownloads() {
    func copy(_ festival: FestivalOverview) -> FestivalListPresentation.PackCopy {
      return FestivalListPresentation.packCopy(
        for: festival,
        now: utc("2026-11-01T03:00:00Z")
      )
    }
    #expect(copy(festival(
      id: "end",
      firstDate: "2026-10-01"
    )) == .ready("팩 받기"))
    #expect(copy(festival(
      id: "endedStale",
      firstDate: "2026-10-01",
      packVersion: 3,
      cachedPackVersion: 2
    )) == .ready("팩 업데이트"))
    #expect(copy(festival(
      id: "endedUnpublished",
      firstDate: "2026-10-01",
      packVersion: 0
    )) == .unavailable("팩 발행을 기다리고 있어요"))
    #expect(copy(festival(
      id: "endedReceived",
      firstDate: "2026-10-01",
      packVersion: 2,
      cachedPackVersion: 2
    ))
      == .received("팩 받음 · 최신 버전"))
    #expect(copy(festival(
      id: "endedNewer",
      firstDate: "2026-10-01",
      packVersion: 2,
      cachedPackVersion: 3
    ))
      == .received("팩 받음 · 최신 버전"))
    #expect(copy(festival(
      id: "lastDay",
      firstDate: "2026-11-01",
      lastDate: "2026-11-01"
    )) == .ready("팩 받기"))
    let discovered = festival(
      id: "soon",
      firstDate: "2026-11-20",
      status: "discovered"
    )
    #expect(copy(discovered) == .ready("팩 받기"))
    #expect(copy(festival(
      id: "unpublished",
      firstDate: "2026-11-20",
      packVersion: 0
    ))
      == .unavailable("팩 발행을 기다리고 있어요"))
    #expect(copy(festival(
      id: "published",
      firstDate: "2026-11-20",
      status: "upcoming"
    )) == .ready("팩 받기"))
    #expect(copy(festival(
      id: "same",
      firstDate: "2026-11-20",
      packVersion: 2,
      cachedPackVersion: 2
    ))
      == .received("팩 받음 · 최신 버전"))
    #expect(copy(festival(
      id: "newer",
      firstDate: "2026-11-20",
      packVersion: 2,
      cachedPackVersion: 3
    ))
      == .received("팩 받음 · 최신 버전"))
    #expect(copy(festival(
      id: "stale",
      firstDate: "2026-11-20",
      packVersion: 3,
      cachedPackVersion: 2
    ))
      == .ready("팩 업데이트"))
  }

  @Test
  func packCopyDependsOnlyOnPublishedAndCachedVersions() {
    for cachedVersion: Int? in [nil, 1, 2, 3] {
      let copy = FestivalListPresentation.packCopy(
        for: festival(
          id: "festival",
          firstDate: "2026-11-20",
          packVersion: 2,
          cachedPackVersion: cachedVersion
        ),
        now: utc("2026-11-01T03:00:00Z")
      )
      if let cachedVersion, cachedVersion >= 2 {
        #expect(copy == .received("팩 받음 · 최신 버전"))
      } else {
        #expect(copy == .ready(cachedVersion == nil ? "팩 받기" : "팩 업데이트"))
      }
    }
  }

  @Test func sortedUsesScheduleDatesBeforeUndatedAndEndedRegardlessOfPackPublication() {
    let now = utc("2026-11-01T03:00:00Z")
    let festivals = [
      festival(
        id: "endedOld",
        firstDate: "2026-10-01",
        lastDate: "2026-10-02"
      ),
      festival(
        id: "far",
        firstDate: "2026-12-01"
      ),
      festival(
        id: "soon",
        firstDate: "2026-11-03",
        status: "discovered",
        packVersion: 0
      ),
      festival(
        id: "endedNew",
        firstDate: "2026-10-20",
        lastDate: "2026-10-21"
      ),
      festival(
        id: "near",
        firstDate: "2026-11-05"
      ),
      festival(
        id: "live",
        firstDate: "2026-10-31",
        lastDate: "2026-11-02"
      ),
      festival(id: "undated")
    ]

    #expect(FestivalListPresentation.sorted(
      festivals,
      now: now
    ).map(\.id)
      == ["live", "soon", "near", "far", "undated", "endedNew", "endedOld"])
  }

  @Test func appendedPagesKeepEndedLastAndUseStableIDsForSameDates() {
    let firstPage = [
      festival(
        id: "ended",
        firstDate: "2026-10-01"
      ),
      festival(
        id: "z",
        firstDate: "2026-12-01"
      )
    ]
    let nextPage = [
      festival(
        id: "near",
        firstDate: "2026-11-02",
        packVersion: 0
      ),
      festival(
        id: "a",
        firstDate: "2026-12-01"
      )
    ]
    let ordered = FestivalListPresentation.sorted(
      firstPage + nextPage,
      now: utc("2026-11-01T03:00:00Z")
    )
    #expect(ordered.map(\.id) == ["near", "a", "z", "ended"])
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
    id: String,
    name: String? = nil,
    venue: String? = nil,
    firstDate: String? = nil,
    lastDate: String? = nil,
    status: String? = nil,
    packVersion: Int = 1,
    cachedPackVersion: Int? = nil
  ) -> FestivalOverview {
    return FestivalOverview(
      item: FestivalCatalogItem(
      id: id,
      name: name ?? id,
      venue: venue,
      firstDate: firstDate,
      lastDate: lastDate,
      packVersion: packVersion,
      status: status
    ),
      isCached: cachedPackVersion != nil,
      cachedPackVersion: cachedPackVersion
    )
  }

  private func utc(_ value: String) -> Date {
    return ISO8601DateFormatter().date(from: value)!
  }
}
