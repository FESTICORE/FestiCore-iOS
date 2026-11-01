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
}
