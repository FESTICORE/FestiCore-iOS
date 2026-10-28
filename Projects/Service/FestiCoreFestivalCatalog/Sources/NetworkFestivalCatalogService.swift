import Alamofire
import FestiCoreFestivalCatalogInterface
import FestiCoreNetworkInterface
import Foundation

public enum FestivalCatalogError: Error, Sendable {
  case invalidResponse
  case repeatedCursor
  case tooManyPages
}

public actor NetworkFestivalCatalogService: FestivalCatalogService {
  private let client: any FestiCoreRequestClient
  private let cacheURL: URL
  private let baseURL: URL?

  public init(client: any FestiCoreRequestClient, cacheURL: URL, baseURL: URL? = nil) {
    self.client = client
    self.cacheURL = cacheURL
    self.baseURL = baseURL
  }

  public nonisolated func imageURL(for value: String?) -> URL? {
    guard let value, let url = URL(string: value) else { return nil }
    if let scheme = url.scheme?.lowercased() {
      guard scheme == "https" || scheme == "http" else { return nil }
      return url
    }
    guard value.hasPrefix("/"), !value.hasPrefix("//"), let baseURL else { return nil }
    return URL(string: value, relativeTo: baseURL)?.absoluteURL
  }

  public func cachedFestivals() throws -> [FestivalCatalogItem] {
    guard FileManager.default.fileExists(atPath: cacheURL.path) else { return [] }
    return try JSONDecoder().decode([FestivalCatalogItem].self, from: Data(contentsOf: cacheURL))
      .map { $0.withThumbnailURL(imageURL(for: $0.thumbnailURL?.absoluteString)) }
  }

  public func refresh() async throws -> [FestivalCatalogItem] {
    var items: [FestivalCatalogItem] = []
    var seenIDs = Set<String>()
    var seenCursors = Set<String>()
    var after: String?

    for _ in 0..<100 {
      let response = try await client.send(FestivalListRequest(after: after))
      guard response.code == "SUCCESS" else { throw FestivalCatalogError.invalidResponse }
      for item in response.data.items where seenIDs.insert(item.id).inserted {
        items.append(item.withThumbnailURL(imageURL(for: item.thumbnailURL?.absoluteString)))
      }
      guard let nextCursor = response.data.nextCursor else {
        let directory = cacheURL.deletingLastPathComponent()
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        try JSONEncoder().encode(items).write(to: cacheURL, options: .atomic)
        return items
      }
      guard seenCursors.insert(nextCursor).inserted else { throw FestivalCatalogError.repeatedCursor }
      after = nextCursor
    }
    throw FestivalCatalogError.tooManyPages
  }
}

private struct FestivalListRequest: FestiCoreDataRequest {
  typealias Response = FestivalListEnvelope
  let after: String?

  var path: String { "api/v1/festivals" }
  var method: HTTPMethod { .get }
  var authorization: FestiCoreAuthorization { .none }
  var parameters: (any Encodable & Sendable)? { FestivalListParameters(after: after, limit: 50) }
}

private struct FestivalListParameters: Encodable, Sendable {
  let after: String?
  let limit: Int
}

private struct FestivalListEnvelope: Decodable, Sendable {
  let code: String
  let data: FestivalListData
}

private struct FestivalListData: Decodable, Sendable {
  let items: [FestivalCatalogItem]
  let nextCursor: String?
}
