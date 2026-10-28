import CryptoKit
import Foundation
import FestiCorePackInterface

public enum PackSyncError: Error, Sendable, Equatable {
  case unconfigured
  case invalidFestivalID
  case invalidEndpoint
  case invalidMessage
  case invalidPack
  case invalidChunk
  case timeout
  case packTooLarge
  case server(String)
}

struct PackCache: Sendable {
  private let directory: URL
  private static let maxBytes = 8 * 1024 * 1024

  init(directory: URL) { self.directory = directory }

  func load(_ festivalID: String) throws -> CachedFestivalPack? {
    let url = try fileURL(for: festivalID)
    guard FileManager.default.fileExists(atPath: url.path) else { return nil }
    let bytes = try Data(contentsOf: url)
    guard bytes.count <= Self.maxBytes * 2,
          let stored = try? JSONDecoder().decode(StoredPack.self, from: bytes),
          stored.festivalID == festivalID,
          Self.isValid(stored.pack, festivalID: festivalID, version: stored.packVersion),
          stored.pack.count <= Self.maxBytes,
          !stored.etag.isEmpty,
          Self.digest(stored.pack) == stored.sha256 else {
      throw PackSyncError.invalidPack
    }
    return CachedFestivalPack(
      festivalID: festivalID, packVersion: stored.packVersion,
      etag: stored.etag, pack: stored.pack
    )
  }

  @discardableResult
  func save(_ value: CachedFestivalPack) throws -> CachedFestivalPack {
    guard value.pack.count <= Self.maxBytes else { throw PackSyncError.packTooLarge }
    guard Self.isValid(value.pack, festivalID: value.festivalID, version: value.packVersion),
          !value.etag.isEmpty, value.etag.utf8.count <= 128 else {
      throw PackSyncError.invalidPack
    }
    if let previous = try load(value.festivalID), previous.packVersion > value.packVersion {
      return previous
    }
    let url = try fileURL(for: value.festivalID)
    try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
    let stored = StoredPack(
      festivalID: value.festivalID, packVersion: value.packVersion,
      etag: value.etag, pack: value.pack, sha256: Self.digest(value.pack)
    )
    try JSONEncoder().encode(stored).write(to: url, options: .atomic)
    return value
  }

  static func digest(_ bytes: Data) -> String {
    SHA256.hash(data: bytes).map { String(format: "%02x", $0) }.joined()
  }

  static func isValid(_ bytes: Data, festivalID: String, version: Int) -> Bool {
    guard version > 0,
          let json = try? JSONSerialization.jsonObject(with: bytes) as? [String: Any],
          json["id"] as? String == festivalID,
          json["packVersion"] as? Int == version else { return false }
    return true
  }

  private func fileURL(for festivalID: String) throws -> URL {
    guard !festivalID.isEmpty, festivalID.count <= 128,
          festivalID.utf8.allSatisfy({ ($0 >= 65 && $0 <= 90) || ($0 >= 97 && $0 <= 122) || ($0 >= 48 && $0 <= 57) || $0 == 45 || $0 == 95 }) else {
      throw PackSyncError.invalidFestivalID
    }
    return directory.appendingPathComponent("\(festivalID).json", isDirectory: false)
  }
}

private struct StoredPack: Codable {
  let festivalID: String
  let packVersion: Int
  let etag: String
  let pack: Data
  let sha256: String
}
