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

  public init(
    id: String, name: String, venue: String? = nil, firstDate: String? = nil,
    lastDate: String? = nil, thumbnailURL: URL? = nil, packVersion: Int,
    status: String? = nil
  ) {
    self.id = id
    self.name = name
    self.venue = venue
    self.firstDate = firstDate
    self.lastDate = lastDate
    self.thumbnailURL = thumbnailURL
    self.packVersion = packVersion
    self.status = status
  }
}
