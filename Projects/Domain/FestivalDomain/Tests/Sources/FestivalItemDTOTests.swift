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

  @Test func malformedArtistAndPerformanceEntriesDoNotDiscardValidSiblings() throws {
    let json = #"""
    {"id":"fst_1","name":"축제","packVersion":1,"artists":[
      null,{"name":12,"performances":[]},
      {"name":"아티스트","performances":[
        null,{"startsAt":null,"date":"2026-11-05"},
        {"startsAt":"2026-11-05T10:00:00.000Z","date":12},
        {"startsAt":"2026-11-05T10:00:00.000Z","date":"2026-11-05","stageName":"메인"}
      ]},
      {"name":"다른 아티스트","performances":null},
      {"name":"공연 누락"}
    ]}
    """#
    let dto = try JSONDecoder().decode(FestivalItemDTO.self, from: Data(json.utf8))
    let artists = try #require(dto.toDomain(imageURL: nil).artists)

    #expect(artists.map(\.name) == ["아티스트", "다른 아티스트", "공연 누락"])
    #expect(artists[0].performances == [
      FestivalCatalogPerformance(startsAt: "2026-11-05T10:00:00.000Z", date: "2026-11-05", stageName: "메인")
    ])
    #expect(artists[1].performances.isEmpty)
    #expect(artists[2].performances.isEmpty)
  }

  @Test func missingNullAndMalformedArtistFieldsRemainUnavailable() throws {
    for suffix in ["", ",\"artists\":null", ",\"artists\":{\"name\":\"wrong type\"}"] {
      let json = "{\"id\":\"fst_1\",\"name\":\"축제\",\"packVersion\":1\(suffix)}"
      let dto = try JSONDecoder().decode(FestivalItemDTO.self, from: Data(json.utf8))
      #expect(dto.toDomain(imageURL: nil).artists == nil)
    }
  }

  @Test func malformedArtistProjectionDoesNotFailFestivalListPage() throws {
    let json = #"""
    {"code":"SUCCESS","message":"ok","data":{"items":[
      {"id":"fst_1","name":"첫 축제","packVersion":1,
       "artists":[{"name":"깨진 공연","performances":[{"startsAt":"2026-11-05"}]},
                  {"name":"정상 공연","performances":[{"startsAt":"2026-11-06T10:00:00.000Z","date":"2026-11-06"}]}]},
      {"id":"fst_2","name":"둘째 축제","packVersion":1,"artists":[]},
      {"id":"fst_3","name":"셋째 축제","packVersion":1}
    ],"nextCursor":"next"}}
    """#
    let response = try JSONDecoder().decode(FestivalListResponseDTO.self, from: Data(json.utf8))

    #expect(response.data.items.map(\.id) == ["fst_1", "fst_2", "fst_3"])
    #expect(response.data.nextCursor == "next")
    #expect(response.data.items[0].toDomain(imageURL: nil).artists?.map(\.name) == ["깨진 공연", "정상 공연"])
    #expect(response.data.items[0].toDomain(imageURL: nil).artists?.map(\.performances.count) == [0, 1])
    #expect(response.data.items[1].toDomain(imageURL: nil).artists == [])
    #expect(response.data.items[2].toDomain(imageURL: nil).artists == nil)
  }
}
