import FestiCoreNetworkInterface
import Foundation

public typealias FestivalListResponseDTO = BaseResponseDTO<FestivalListDataDTO>

public struct FestivalListDataDTO: Decodable, Sendable {
  public let items: [FestivalItemDTO]
  public let nextCursor: String?
}

public struct FestivalItemDTO: Codable, Sendable {
  public let id: String
  public let name: String
  public let venue: String?
  public let firstDate: String?
  public let lastDate: String?
  public let thumbUrl: String?
  public let packVersion: Int
  public let status: String?
  public let ticketLinks: FestivalTicketLinksDTO?
  public let artists: [FestivalCatalogArtistDTO]?

  private enum CodingKeys: String, CodingKey {
    case id, name, venue, firstDate, lastDate, thumbUrl, packVersion, status, ticketLinks, artists
  }

  public init(from decoder: Decoder) throws {
    let container = try decoder.container(keyedBy: CodingKeys.self)
    id = try container.decode(String.self, forKey: .id)
    name = try container.decode(String.self, forKey: .name)
    venue = try container.decodeIfPresent(String.self, forKey: .venue)
    firstDate = try container.decodeIfPresent(String.self, forKey: .firstDate)
    lastDate = try container.decodeIfPresent(String.self, forKey: .lastDate)
    thumbUrl = try container.decodeIfPresent(String.self, forKey: .thumbUrl)
    packVersion = try container.decode(Int.self, forKey: .packVersion)
    status = try container.decodeIfPresent(String.self, forKey: .status)
    ticketLinks = try container.decodeIfPresent(FestivalTicketLinksDTO.self, forKey: .ticketLinks)
    artists = (try? container.decodeIfPresent(LossyArray<FestivalCatalogArtistDTO>.self, forKey: .artists))?.items
  }

  public func encode(to encoder: Encoder) throws {
    var container = encoder.container(keyedBy: CodingKeys.self)
    try container.encode(id, forKey: .id)
    try container.encode(name, forKey: .name)
    try container.encodeIfPresent(venue, forKey: .venue)
    try container.encodeIfPresent(firstDate, forKey: .firstDate)
    try container.encodeIfPresent(lastDate, forKey: .lastDate)
    try container.encodeIfPresent(thumbUrl, forKey: .thumbUrl)
    try container.encode(packVersion, forKey: .packVersion)
    try container.encodeIfPresent(status, forKey: .status)
    try container.encodeIfPresent(ticketLinks, forKey: .ticketLinks)
    try container.encodeIfPresent(artists, forKey: .artists)
  }
}

public struct FestivalCatalogArtistDTO: Codable, Sendable {
  public let name: String
  public let performances: [FestivalCatalogPerformanceDTO]

  private enum CodingKeys: String, CodingKey {
    case name, performances
  }

  public init(from decoder: Decoder) throws {
    let container = try decoder.container(keyedBy: CodingKeys.self)
    name = try container.decode(String.self, forKey: .name)
    performances = (try? container.decodeIfPresent(LossyArray<FestivalCatalogPerformanceDTO>.self, forKey: .performances))?.items ?? []
  }
}

public struct FestivalCatalogPerformanceDTO: Codable, Sendable {
  public let startsAt: String
  public let date: String
  public let stageName: String?
}

private struct LossyArray<Element: Decodable & Sendable>: Decodable, Sendable {
  let items: [Element]

  init(from decoder: Decoder) throws {
    var container = try decoder.unkeyedContainer()
    var result: [Element] = []
    while !container.isAtEnd {
      if (try? container.decodeNil()) == true { continue }
      if let element = try? container.decode(Element.self) {
        result.append(element)
      } else {
        _ = try? container.decode(Skipped.self)
      }
    }
    items = result
  }

  private struct Skipped: Decodable {
    init(from decoder: Decoder) throws {}
  }
}

public struct FestivalTicketLinkDTO: Codable, Sendable, Equatable {
  public let label: String
  public let url: String
}

/// 원소 하나가 깨져도 나머지 링크와 축제 항목은 살린다.
public struct FestivalTicketLinksDTO: Codable, Sendable, Equatable {
  public let items: [FestivalTicketLinkDTO]

  public init(items: [FestivalTicketLinkDTO]) {
    self.items = items
  }

  public init(from decoder: Decoder) throws {
    guard var container = try? decoder.unkeyedContainer() else {
      items = []
      return
    }
    var result: [FestivalTicketLinkDTO] = []
    while !container.isAtEnd {
      if (try? container.decodeNil()) == true { continue }
      if let link = try? container.decode(FestivalTicketLinkDTO.self) {
        result.append(link)
      } else {
        _ = try? container.decode(Skipped.self)
      }
    }
    items = result
  }

  public func encode(to encoder: Encoder) throws {
    var container = encoder.singleValueContainer()
    try container.encode(items)
  }

  private struct Skipped: Decodable {
    init(from decoder: Decoder) throws {}
  }
}
