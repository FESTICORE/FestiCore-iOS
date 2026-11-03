import FestivalDomain
import FestivalDomainInterface
import Foundation
import Testing

struct FestivalItemDTOTests {
  @Test func malformedTicketLinksAreDroppedWithoutLosingFestival() throws {
    let json = #"""
    {"id":"fst_1","name":"축제","packVersion":1,"status":"upcoming",
     "ticketLinks":[null,{"label":1,"url":"https://x.com"},"text",
       {"label":"구","url":"http://old.com"},{"label":" ","url":"https://blank.com"},
       {"label":"멜론티켓","url":"https://ticket.melon.com/a"}]}
    """#
    let dto = try JSONDecoder().decode(FestivalItemDTO.self, from: Data(json.utf8))
    let item = dto.toDomain(imageURL: nil)

    #expect(item.ticketLinks == [FestivalTicketLink(label: "멜론티켓", url: URL(string: "https://ticket.melon.com/a")!)])
    #expect(item.status == "upcoming")
  }

  @Test func cachedCatalogWithoutTicketLinksStillDecodesAndRoundTrips() throws {
    let old = #"{"id":"fst_1","name":"축제","packVersion":1}"#
    let dto = try JSONDecoder().decode(FestivalItemDTO.self, from: Data(old.utf8))
    #expect(dto.toDomain(imageURL: nil).ticketLinks.isEmpty)

    let withLinks = #"{"id":"fst_2","name":"축제","packVersion":1,"ticketLinks":[{"label":"예스24","url":"https://ticket.yes24.com/1"}]}"#
    let decoded = try JSONDecoder().decode(FestivalItemDTO.self, from: Data(withLinks.utf8))
    let reencoded = try JSONDecoder().decode(FestivalItemDTO.self, from: JSONEncoder().encode(decoded))
    #expect(reencoded.toDomain(imageURL: nil).ticketLinks.map(\.label) == ["예스24"])
  }

  @Test func artistProjectionPreservesMissingAndExplicitEmptyValues() throws {
    let old = #"{"id":"fst_1","name":"축제","packVersion":1}"#
    let oldDTO = try JSONDecoder().decode(FestivalItemDTO.self, from: Data(old.utf8))
    #expect(oldDTO.toDomain(imageURL: nil).artists == nil)
    let oldCache = String(decoding: try JSONEncoder().encode(oldDTO), as: UTF8.self)
    #expect(!oldCache.contains("artists"))

    let empty = #"{"id":"fst_1","name":"축제","packVersion":1,"artists":[]}"#
    let emptyDTO = try JSONDecoder().decode(FestivalItemDTO.self, from: Data(empty.utf8))
    #expect(emptyDTO.toDomain(imageURL: nil).artists == [])
    let emptyCache = try JSONDecoder().decode(FestivalItemDTO.self, from: JSONEncoder().encode(emptyDTO))
    #expect(emptyCache.toDomain(imageURL: nil).artists == [])
  }

  @Test func artistPerformancesSurviveDTOCacheRoundTrip() throws {
    let json = #"{"id":"fst_1","name":"축제","packVersion":1,"artists":[{"name":"아티스트","performances":[{"startsAt":"2026-11-05T10:00:00.000Z","date":"2026-11-05","stageName":"메인 스테이지"}]}]}"#
    let dto = try JSONDecoder().decode(FestivalItemDTO.self, from: Data(json.utf8))
    let cachedDTO = try JSONDecoder().decode(FestivalItemDTO.self, from: JSONEncoder().encode(dto))
    #expect(cachedDTO.toDomain(imageURL: nil).artists == [
      FestivalCatalogArtist(name: "아티스트", performances: [
        FestivalCatalogPerformance(startsAt: "2026-11-05T10:00:00.000Z", date: "2026-11-05", stageName: "메인 스테이지")
      ])
    ])

    let withoutStage = #"{"id":"fst_1","name":"축제","packVersion":1,"artists":[{"name":"아티스트","performances":[{"startsAt":"2026-11-05T10:00:00.000Z","date":"2026-11-05","stageName":null}]}]}"#
    let nullableDTO = try JSONDecoder().decode(FestivalItemDTO.self, from: Data(withoutStage.utf8))
    #expect(nullableDTO.toDomain(imageURL: nil).artists?.first?.performances.first?.stageName == nil)
    let cachedNullable = try JSONDecoder().decode(FestivalItemDTO.self, from: JSONEncoder().encode(nullableDTO))
    #expect(cachedNullable.toDomain(imageURL: nil).artists?.first?.performances.first?.stageName == nil)
  }
}
