import Foundation

public protocol FestivalCatalogService: Sendable {
  func cachedFestivals() async throws -> [FestivalCatalogItem]
  func refresh() async throws -> [FestivalCatalogItem]
  func page(
    after: String?,
    limit: Int
  ) async throws -> FestivalCatalogPage
  func imageURL(for value: String?) -> URL?
}

public extension FestivalCatalogService {
  func page(
    after: String?,
    limit: Int
  ) async throws -> FestivalCatalogPage {
    return FestivalCatalogPage(items: try await refresh(), nextCursor: nil)
  }
  func imageURL(for value: String?) -> URL? {
    guard let value, let url = URL(string: value),
          url.scheme?.lowercased() == "https", url.host != nil else { return nil }
    return url
  }
}
