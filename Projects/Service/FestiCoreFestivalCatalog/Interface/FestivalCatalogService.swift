import Dependencies
import Foundation

public struct FestivalCatalogItem: Codable, Identifiable, Sendable, Equatable {
  public let id: String
  public let name: String
  public let venue: String?
  public let firstDate: String?
  public let lastDate: String?
  public let thumbnailURL: URL?
  public let packVersion: Int
  public let status: String?

  public init(
    id: String,
    name: String,
    venue: String? = nil,
    firstDate: String? = nil,
    lastDate: String? = nil,
    thumbnailURL: URL? = nil,
    packVersion: Int,
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

  public func withThumbnailURL(_ url: URL?) -> Self {
    Self(
      id: id, name: name, venue: venue, firstDate: firstDate, lastDate: lastDate,
      thumbnailURL: url, packVersion: packVersion, status: status
    )
  }

  private enum CodingKeys: String, CodingKey {
    case id, name, venue, firstDate, lastDate, packVersion, status
    case thumbnailURL = "thumbUrl"
  }
}

public protocol FestivalCatalogService: Sendable {
  func cachedFestivals() async throws -> [FestivalCatalogItem]
  func refresh() async throws -> [FestivalCatalogItem]
  func imageURL(for value: String?) -> URL?
}

public extension FestivalCatalogService {
  func imageURL(for value: String?) -> URL? { value.flatMap(URL.init(string:)) }
}

public enum FestivalCatalogServiceDependency: TestDependencyKey {
  public static var testValue: any FestivalCatalogService { UnimplementedFestivalCatalogService() }
}

public extension DependencyValues {
  var festivalCatalogService: any FestivalCatalogService {
    get { self[FestivalCatalogServiceDependency.self] }
    set { self[FestivalCatalogServiceDependency.self] = newValue }
  }
}

private struct UnimplementedFestivalCatalogService: FestivalCatalogService {
  func cachedFestivals() async throws -> [FestivalCatalogItem] {
    fatalError("festivalCatalogService 미등록")
  }

  func refresh() async throws -> [FestivalCatalogItem] {
    fatalError("festivalCatalogService 미등록")
  }
}
