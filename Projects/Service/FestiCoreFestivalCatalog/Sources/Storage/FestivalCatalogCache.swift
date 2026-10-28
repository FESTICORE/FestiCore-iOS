import Foundation
import FestivalDomain

struct FestivalCatalogCache {
  let url: URL

  func load() throws -> [FestivalItemDTO] {
    guard FileManager.default.fileExists(atPath: url.path) else { return [] }
    return try JSONDecoder().decode([FestivalItemDTO].self, from: Data(contentsOf: url))
  }

  func save(_ items: [FestivalItemDTO]) throws {
    try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
    try JSONEncoder().encode(items).write(to: url, options: .atomic)
  }
}
