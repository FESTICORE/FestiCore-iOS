import FestivalDomain
import FestivalDomainInterface
import FestiCoreNetworkInterface
import Foundation

public actor NetworkFestivalCatalogService: FestivalCatalogService {
  private let client: any FestiCoreRequestClient
  private let cache: FestivalCatalogCache
  private let imageResolver: FestivalImageURLResolver
  private var pageItems: [FestivalItemDTO] = []

  public init(client: any FestiCoreRequestClient, cacheURL: URL, baseURL: URL? = nil) {
    self.client = client
    cache = FestivalCatalogCache(url: cacheURL)
    imageResolver = FestivalImageURLResolver(baseURL: baseURL)
  }

  public nonisolated func imageURL(for value: String?) -> URL? {
    imageResolver.resolve(value)
  }

  public func cachedFestivals() throws -> [FestivalCatalogItem] {
    try cache.load().map { $0.toDomain(imageURL: imageResolver.resolve($0.thumbUrl)) }
  }

  public func festivalDetail(for festivalID: String) async throws -> FestivalPackDocument {
    guard !festivalID.isEmpty,
          festivalID.rangeOfCharacter(from: CharacterSet(charactersIn: "/?#")) == nil else {
      throw FestivalCatalogError.invalidResponse
    }
    let response = try await client.send(FestivalDetailRequest(festivalID: festivalID))
    guard response.code == "SUCCESS", response.data.id == festivalID else {
      throw FestivalCatalogError.invalidResponse
    }
    return response.data
  }

  public func refresh() async throws -> [FestivalCatalogItem] {
    var items: [FestivalItemDTO] = []
    var seenIDs = Set<String>()
    var seenCursors = Set<String>()
    var after: String?

    for _ in 0..<100 {
      let response = try await client.send(FestivalListRequest(
        after: after,
        limit: 50
      ))
      guard response.code == "SUCCESS" else { throw FestivalCatalogError.invalidResponse }
      for item in response.data.items where seenIDs.insert(item.id).inserted { items.append(item) }
      guard let nextCursor = response.data.nextCursor else {
        try cache.save(items)
        return items.map { $0.toDomain(imageURL: imageResolver.resolve($0.thumbUrl)) }
      }
      guard seenCursors.insert(nextCursor).inserted else { throw FestivalCatalogError.repeatedCursor }
      after = nextCursor
    }
    throw FestivalCatalogError.tooManyPages
  }

  public func page(
    after: String?,
    limit: Int
  ) async throws -> FestivalCatalogPage {
    let response = try await client.send(FestivalListRequest(
      after: after,
      limit: limit
    ))
    guard response.code == "SUCCESS" else { throw FestivalCatalogError.invalidResponse }
    if response.data.nextCursor == after, after != nil { throw FestivalCatalogError.repeatedCursor }
    let items = response.data.items
    if after == nil { pageItems = [] }
    var known = Set(pageItems.map(\.id))
    pageItems += items.filter { known.insert($0.id).inserted }
    if response.data.nextCursor == nil { try cache.save(pageItems) }
    return FestivalCatalogPage(
      items: items.map { $0.toDomain(imageURL: imageResolver.resolve($0.thumbUrl)) },
      nextCursor: response.data.nextCursor
    )
  }
}
