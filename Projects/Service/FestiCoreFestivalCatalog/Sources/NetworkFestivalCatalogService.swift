import FestivalDomain
import FestivalDomainInterface
import FestiCoreNetworkInterface
import Foundation

public actor NetworkFestivalCatalogService: FestivalCatalogService {
  private let client: any FestiCoreRequestClient
  private let cache: FestivalCatalogCache
  private let imageResolver: FestivalImageURLResolver

  public init(client: any FestiCoreRequestClient, cacheURL: URL, baseURL: URL? = nil) {
    self.client = client
    cache = FestivalCatalogCache(url: cacheURL)
    imageResolver = FestivalImageURLResolver(baseURL: baseURL)
  }

  public nonisolated func imageURL(for value: String?) -> URL? {
    imageResolver.resolve(value)
  }

  public func cachedFestivals() throws -> [FestivalCatalogItem] {
    try cache.load().map { $0.toEntity(imageURL: imageResolver.resolve($0.thumbUrl)) }
  }

  public func refresh() async throws -> [FestivalCatalogItem] {
    var items: [FestivalItemDTO] = []
    var seenIDs = Set<String>()
    var seenCursors = Set<String>()
    var after: String?

    for _ in 0..<100 {
      let response = try await client.send(FestivalListRequest(after: after))
      guard response.code == "SUCCESS" else { throw FestivalCatalogError.invalidResponse }
      for item in response.data.items where seenIDs.insert(item.id).inserted { items.append(item) }
      guard let nextCursor = response.data.nextCursor else {
        try cache.save(items)
        return items.map { $0.toEntity(imageURL: imageResolver.resolve($0.thumbUrl)) }
      }
      guard seenCursors.insert(nextCursor).inserted else { throw FestivalCatalogError.repeatedCursor }
      after = nextCursor
    }
    throw FestivalCatalogError.tooManyPages
  }
}
