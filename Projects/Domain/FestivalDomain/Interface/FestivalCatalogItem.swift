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

  public init(
    id: String, name: String, venue: String? = nil, firstDate: String? = nil,
    lastDate: String? = nil, thumbnailURL: URL? = nil, packVersion: Int,
    status: String? = nil, ticketLinks: [FestivalTicketLink] = []
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
