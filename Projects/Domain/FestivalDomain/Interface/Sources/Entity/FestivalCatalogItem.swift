import Foundation

public struct FestivalCatalogItem: Identifiable, Sendable, Equatable {
  public let id: String
  public let name: String
  public let venue: String?
  public let firstDate: String?
  public let lastDate: String?
  public let thumbnailURL: URL?
  public let packVersion: Int
  public let status: String?
  public let ticketLinks: [FestivalTicketLink]
  /// nil은 이전 서버 응답이나 캐시에 이 필드가 없었다는 뜻이다.
  public let artists: [FestivalCatalogArtist]?

  public init(
    id: String, name: String, venue: String? = nil, firstDate: String? = nil,
    lastDate: String? = nil, thumbnailURL: URL? = nil, packVersion: Int,
    status: String? = nil, ticketLinks: [FestivalTicketLink] = [],
    artists: [FestivalCatalogArtist]? = nil
  ) {
    self.id = id
    self.name = name
    self.venue = venue
    self.firstDate = firstDate
    self.lastDate = lastDate
    self.thumbnailURL = thumbnailURL
    self.packVersion = packVersion
    self.status = status
    self.ticketLinks = ticketLinks
    self.artists = artists
  }
}

public struct FestivalCatalogArtist: Sendable, Equatable {
  public let name: String
  public let performances: [FestivalCatalogPerformance]

  public init(name: String, performances: [FestivalCatalogPerformance]) {
    self.name = name
    self.performances = performances
  }
}

public struct FestivalCatalogPerformance: Sendable, Equatable {
  public let startsAt: String
  public let date: String
  public let stageName: String?

  public init(startsAt: String, date: String, stageName: String?) {
    self.startsAt = startsAt
    self.date = date
    self.stageName = stageName
  }
}

/// 예매처 링크. https 주소만 담는다.
public struct FestivalTicketLink: Sendable, Equatable {
  public let label: String
  public let url: URL

  public init(label: String, url: URL) {
    self.label = label
    self.url = url
  }
}
