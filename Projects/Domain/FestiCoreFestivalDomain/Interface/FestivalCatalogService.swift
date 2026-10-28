import Foundation

public protocol FestivalCatalogService: Sendable {
  func cachedFestivals() async throws -> [FestivalCatalogItem]
  func refresh() async throws -> [FestivalCatalogItem]
  func imageURL(for value: String?) -> URL?
}

public extension FestivalCatalogService {
  func imageURL(for value: String?) -> URL? {
    guard let value, let url = URL(string: value),
          url.scheme?.lowercased() == "https", url.host != nil else { return nil }
    return url
  }
}
