import Foundation

public protocol FestivalCatalogService: Sendable {
  func cachedFestivals() async throws -> [FestivalCatalogItem]
  func refresh() async throws -> [FestivalCatalogItem]
  func imageURL(for value: String?) -> URL?
}

public extension FestivalCatalogService {
  func imageURL(for value: String?) -> URL? { value.flatMap(URL.init(string:)) }
}
