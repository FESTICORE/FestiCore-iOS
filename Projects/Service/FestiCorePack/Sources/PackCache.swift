import CryptoKit
import Foundation
import FestiCorePackInterface
import SQLiteData

@Table("cachedFestivalPacks")
private struct CachedPackRecord: Sendable {
  @Column(primaryKey: true)
  let festivalID: String
  let packVersion: Int
  let etag: String
  let pack: Data
  let sha256: String
  let checkedAt: Double
}

struct PackCache: Sendable {
  private let directory: URL
  private let database: (any DatabaseWriter)?
  private static let maxBytes = 8 * 1024 * 1024

  init(
    directory: URL,
    database: (any DatabaseWriter)? = nil
  ) {
    self.directory = directory
    self.database = database
  }

  func load(_ festivalID: String) throws -> CachedFestivalPack? {
    let url = try fileURL(for: festivalID)
    if let database {
      if let record = try database.read({ db in try CachedPackRecord.find(festivalID).fetchOne(db) }) {
        let current: CachedFestivalPack
        do {
          current = try validated(record)
        } catch {
          guard let backup = try loadFile(festivalID, at: url) else { throw error }
          try saveToDatabase(backup, checkedAt: backup.checkedAt ?? Date(), database: database)
          return backup
        }
        if let file = try? loadFile(festivalID, at: url),
           file.packVersion > current.packVersion ||
             (file.packVersion == current.packVersion &&
              (file.checkedAt ?? .distantPast) > (current.checkedAt ?? .distantPast) &&
              (file.etag != current.etag || file.pack != current.pack)) {
          try saveToDatabase(file, checkedAt: file.checkedAt ?? Date(), database: database)
          return file
        }
        return current
      }
      guard let legacy = try loadFile(festivalID, at: url) else { return nil }
      try saveToDatabase(legacy, checkedAt: legacy.checkedAt ?? Date(), database: database)
      return legacy
    }
    return try loadFile(festivalID, at: url)
  }

  private func loadFile(
    _ festivalID: String,
    at url: URL
  ) throws -> CachedFestivalPack? {
    guard FileManager.default.fileExists(atPath: url.path) else { return nil }
    let bytes = try Data(contentsOf: url)
    guard bytes.count <= Self.maxBytes * 2,
          let stored = try? JSONDecoder().decode(StoredPack.self, from: bytes),
          stored.festivalID == festivalID,
          Self.isValid(stored.pack, festivalID: festivalID, version: stored.packVersion),
          stored.pack.count <= Self.maxBytes,
          !stored.etag.isEmpty, stored.etag.utf8.count <= 128,
          Self.digest(stored.pack) == stored.sha256 else {
      throw PackSyncError.invalidPack
    }
    let checkedAt = try? url.resourceValues(forKeys: [.contentModificationDateKey]).contentModificationDate
    return CachedFestivalPack(
      festivalID: festivalID, packVersion: stored.packVersion,
      etag: stored.etag, pack: stored.pack, checkedAt: checkedAt
    )
  }

  func delete(_ festivalID: String) throws {
    let url = try fileURL(for: festivalID)
    guard let database else {
      if FileManager.default.fileExists(atPath: url.path) {
        try FileManager.default.removeItem(at: url)
      }
      return
    }
    let quarantine = url.appendingPathExtension("deleting-\(UUID().uuidString)")
    let hasFile = FileManager.default.fileExists(atPath: url.path)
    if hasFile { try FileManager.default.moveItem(at: url, to: quarantine) }
    do {
      try database.write { db in
        try CachedPackRecord.find(festivalID).delete().execute(db)
      }
    } catch {
      if hasFile { try? FileManager.default.moveItem(at: quarantine, to: url) }
      throw error
    }
    // DB 삭제에 성공했다면 격리 파일은 목록에 다시 나타나지 않는다.
    if hasFile { try? FileManager.default.removeItem(at: quarantine) }
  }

  /// 서버가 같은 버전이라고 답하면 마지막 확인 시각을 갱신한다.
  func markChecked(_ festivalID: String, at date: Date = Date()) throws {
    if let database {
      if let record = try database.read({ db in try CachedPackRecord.find(festivalID).fetchOne(db) }) {
        try database.write { db in
          try CachedPackRecord.upsert {
            CachedPackRecord(
              festivalID: record.festivalID, packVersion: record.packVersion,
              etag: record.etag, pack: record.pack, sha256: record.sha256,
              checkedAt: date.timeIntervalSince1970
            )
          }.execute(db)
        }
        let url = try fileURL(for: festivalID)
        if FileManager.default.fileExists(atPath: url.path) {
          try FileManager.default.setAttributes(
            [.modificationDate: date], ofItemAtPath: url.path
          )
        }
        return
      }
      guard try load(festivalID) != nil else { return }
      return try markChecked(festivalID, at: date)
    }
    let url = try fileURL(for: festivalID)
    guard FileManager.default.fileExists(atPath: url.path) else { return }
    try FileManager.default.setAttributes([.modificationDate: date], ofItemAtPath: url.path)
  }

  func loadAll() throws -> [CachedFestivalPack] {
    var packs: [String: CachedFestivalPack] = [:]
    if let database {
      let records = try database.read { db in try CachedPackRecord.all.fetchAll(db) }
      for record in records {
        if let value = try loadListedPack(record.festivalID) {
          packs[value.festivalID] = value
        }
      }
    }
    guard FileManager.default.fileExists(atPath: directory.path) else {
      return packs.values.sorted { $0.festivalID < $1.festivalID }
    }
    let files = try FileManager.default.contentsOfDirectory(
      at: directory,
      includingPropertiesForKeys: [.isRegularFileKey, .isSymbolicLinkKey, .fileSizeKey],
      options: [.skipsHiddenFiles]
    )
    for file in files where file.pathExtension == "json" {
      guard let properties = try? file.resourceValues(forKeys: [
        .isRegularFileKey, .isSymbolicLinkKey, .fileSizeKey
      ]),
        properties.isRegularFile == true,
        properties.isSymbolicLink != true,
        (properties.fileSize ?? Int.max) <= Self.maxBytes * 2,
        let pack = try loadListedPack(file.deletingPathExtension().lastPathComponent)
      else { continue }
      packs[pack.festivalID] = pack
    }
    return packs.values.sorted { $0.festivalID < $1.festivalID }
  }

  /// 손상 항목만 목록에서 제외한다. DB와 파일 시스템 접근 오류는 호출자에게 전달한다.
  private func loadListedPack(_ festivalID: String) throws -> CachedFestivalPack? {
    do {
      return try load(festivalID)
    } catch PackSyncError.invalidPack {
      return nil
    } catch PackSyncError.invalidFestivalID {
      return nil
    }
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
    if let database {
      try saveToDatabase(value, checkedAt: Date(), database: database)
    }
    return value
  }

  static func digest(_ bytes: Data) -> String {
    return SHA256.hash(data: bytes).map { String(format: "%02x", $0) }.joined()
  }

  static func isValid(_ bytes: Data, festivalID: String, version: Int) -> Bool {
    guard version > 0,
          let json = try? JSONSerialization.jsonObject(with: bytes) as? [String: Any],
          json["id"] as? String == festivalID,
          json["packVersion"] as? Int == version else { return false }
    return true
  }

  private func validated(_ record: CachedPackRecord) throws -> CachedFestivalPack {
    guard record.pack.count <= Self.maxBytes,
          Self.isValid(record.pack, festivalID: record.festivalID, version: record.packVersion),
          !record.etag.isEmpty, record.etag.utf8.count <= 128,
          Self.digest(record.pack) == record.sha256 else {
      throw PackSyncError.invalidPack
    }
    return CachedFestivalPack(
      festivalID: record.festivalID, packVersion: record.packVersion,
      etag: record.etag, pack: record.pack,
      checkedAt: Date(timeIntervalSince1970: record.checkedAt)
    )
  }

  private func saveToDatabase(
    _ value: CachedFestivalPack,
    checkedAt: Date,
    database: any DatabaseWriter
  ) throws {
    let record = CachedPackRecord(
      festivalID: value.festivalID, packVersion: value.packVersion,
      etag: value.etag, pack: value.pack, sha256: Self.digest(value.pack),
      checkedAt: checkedAt.timeIntervalSince1970
    )
    try database.write { db in
      try CachedPackRecord.upsert { record }.execute(db)
    }
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
