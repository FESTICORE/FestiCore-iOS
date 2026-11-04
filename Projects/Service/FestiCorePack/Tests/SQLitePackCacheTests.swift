import Foundation
import SQLiteData
import Testing
import FestiCorePackInterface
@testable import FestiCorePack

@Suite("SQLite 오프라인 팩 캐시")
struct SQLitePackCacheTests {
  @Test("기존 JSON 팩을 SQLite로 옮기고 파일 복구본도 유지한다")
  func importsLegacyFile() throws {
    let directory = temporaryDirectory()
    let value = pack(version: 1)
    try PackCache(directory: directory).save(value)
    let database = try testDatabase()
    let cache = PackCache(directory: directory, database: database)

    #expect(try cache.load(value.festivalID)?.pack == value.pack)
    #expect(FileManager.default.fileExists(atPath: directory.appendingPathComponent("fst_example.json").path))
    #expect(try PackCache(directory: directory, database: database).loadAll().map(\.festivalID) == [value.festivalID])
  }

  @Test("삭제한 팩은 이전 JSON에서 다시 나타나지 않는다")
  func deleteRemovesBothStores() throws {
    let directory = temporaryDirectory()
    let value = pack(version: 1)
    try PackCache(directory: directory).save(value)
    let database = try testDatabase()
    let cache = PackCache(directory: directory, database: database)
    try cache.delete(value.festivalID)

    #expect(try cache.load(value.festivalID) == nil)
    #expect(try cache.loadAll().isEmpty)
    #expect(!FileManager.default.fileExists(atPath: directory.appendingPathComponent("fst_example.json").path))
  }

  @Test("새 버전 갱신과 확인 시각을 SQLite에 보존한다")
  func updatesAndMarksChecked() throws {
    let directory = temporaryDirectory()
    let database = try testDatabase()
    let cache = PackCache(directory: directory, database: database)
    try cache.save(pack(version: 1))
    try cache.save(pack(version: 2))
    let checkedAt = Date(timeIntervalSince1970: 1_800_000_000)
    try cache.markChecked("fst_example", at: checkedAt)

    let reloaded = try PackCache(directory: directory, database: database).load("fst_example")
    #expect(reloaded?.packVersion == 2)
    #expect(reloaded?.checkedAt == checkedAt)
    #expect(try cache.save(pack(version: 1)).packVersion == 2)
    #expect(try PackCache(directory: directory).load("fst_example")?.packVersion == 2)
  }

  @Test("파일 쓰기 후 DB 갱신이 끊겨도 다음 읽기에서 새 버전을 복구한다")
  func recoversNewerFileThanDatabase() throws {
    let directory = temporaryDirectory()
    let database = try testDatabase()
    let cache = PackCache(directory: directory, database: database)
    try cache.save(pack(version: 1))
    try PackCache(directory: directory).save(pack(version: 2))

    #expect(try cache.load("fst_example")?.packVersion == 2)
    #expect(try PackCache(directory: directory, database: database).loadAll().first?.packVersion == 2)
  }

  @Test("손상된 DB 행은 정상 JSON으로 복구하고 양쪽이 손상되면 오류를 드러낸다")
  func validatesChecksumAndSize() throws {
    let directory = temporaryDirectory()
    let database = try testDatabase()
    let cache = PackCache(directory: directory, database: database)
    let value = pack(version: 1)
    try cache.save(value)
    try database.write { db in
      try #sql("UPDATE cachedFestivalPacks SET sha256 = 'invalid' WHERE festivalID = 'fst_example'").execute(db)
    }
    #expect(try cache.load(value.festivalID)?.pack == value.pack)
    #expect(try cache.loadAll().map(\.festivalID) == [value.festivalID])
    try FileManager.default.removeItem(at: directory.appendingPathComponent("fst_example.json"))
    #expect(try cache.load(value.festivalID)?.pack == value.pack)

    try database.write { db in
      try #sql("UPDATE cachedFestivalPacks SET sha256 = 'invalid' WHERE festivalID = 'fst_example'").execute(db)
    }
    #expect(throws: PackSyncError.invalidPack) { try cache.load(value.festivalID) }
    #expect(try cache.loadAll().isEmpty)

    let oversized = CachedFestivalPack(
      festivalID: value.festivalID, packVersion: 2, etag: "\"two\"",
      pack: Data(repeating: 0, count: 8 * 1024 * 1024 + 1)
    )
    #expect(throws: PackSyncError.packTooLarge) { try cache.save(oversized) }
  }

  @Test("손상된 JSON 하나가 정상 팩 목록을 지우지 않는다")
  func loadAllSkipsCorruptedLegacyFile() throws {
    let directory = temporaryDirectory()
    defer { try? FileManager.default.removeItem(at: directory) }
    let cache = PackCache(directory: directory)
    let expected = [pack(id: "fst_a", version: 1), pack(id: "fst_b", version: 2)]
    for value in expected { try cache.save(value) }
    try Data("invalid json".utf8).write(to: directory.appendingPathComponent("fst_corrupt.json"))

    #expect(throws: PackSyncError.invalidPack) { try cache.load("fst_corrupt") }
    #expect(try cache.loadAll() == expected)
  }

  @Test("복구본 없는 손상 SQLite 행 하나가 정상 팩 목록을 지우지 않는다")
  func loadAllSkipsCorruptedDatabaseRecord() throws {
    let directory = temporaryDirectory()
    defer { try? FileManager.default.removeItem(at: directory) }
    let database = try testDatabase()
    let cache = PackCache(directory: directory, database: database)
    let expected = [pack(id: "fst_a", version: 1), pack(id: "fst_b", version: 2)]
    for value in expected { try cache.save(value) }
    try cache.save(pack(id: "fst_corrupt", version: 1))
    try FileManager.default.removeItem(at: directory.appendingPathComponent("fst_corrupt.json"))
    try database.write { db in
      try #sql("UPDATE cachedFestivalPacks SET sha256 = 'invalid' WHERE festivalID = 'fst_corrupt'").execute(db)
    }

    #expect(throws: PackSyncError.invalidPack) { try cache.load("fst_corrupt") }
    #expect(try cache.loadAll() == expected)
  }

  @Test("DB 목록 조회 실패는 빈 목록으로 숨기지 않는다")
  func loadAllPropagatesDatabaseQueryFailure() throws {
    let database = try testDatabase()
    try database.write { db in try #sql("DROP TABLE cachedFestivalPacks").execute(db) }
    let cache = PackCache(directory: temporaryDirectory(), database: database)

    #expect(throws: (any Error).self) { try cache.loadAll() }
  }

  @Test("DB 삭제 실패 시 파일을 되돌리고 재시도 후 두 저장소에서 제거한다")
  func failedDeleteKeepsPackUntilRetry() throws {
    let directory = temporaryDirectory()
    let database = try testDatabase()
    let cache = PackCache(directory: directory, database: database)
    let value = pack(version: 1)
    try cache.save(value)
    try database.write { db in
      try #sql("""
        CREATE TRIGGER preventPackDelete BEFORE DELETE ON cachedFestivalPacks
        BEGIN SELECT RAISE(ABORT, 'delete unavailable'); END
        """).execute(db)
    }
    do {
      try cache.delete(value.festivalID)
      Issue.record("DB 삭제 실패가 전달되어야 한다")
    } catch {}
    #expect(try cache.load(value.festivalID)?.pack == value.pack)
    #expect(FileManager.default.fileExists(atPath: directory.appendingPathComponent("fst_example.json").path))

    try database.write { db in try #sql("DROP TRIGGER preventPackDelete").execute(db) }
    try cache.delete(value.festivalID)
    #expect(try cache.load(value.festivalID) == nil)
    #expect(try cache.loadAll().isEmpty)
  }

  private func pack(id: String = "fst_example", version: Int) -> CachedFestivalPack {
    return CachedFestivalPack(
      festivalID: id, packVersion: version, etag: "\"v\(version)\"",
      pack: Data("{\"id\":\"\(id)\",\"packVersion\":\(version)}".utf8)
    )
  }

  private func testDatabase() throws -> any DatabaseWriter {
    let database = try DatabaseQueue()
    try database.write { db in
      try #sql("""
        CREATE TABLE cachedFestivalPacks (
          festivalID TEXT PRIMARY KEY NOT NULL,
          packVersion INTEGER NOT NULL,
          etag TEXT NOT NULL,
          pack BLOB NOT NULL,
          sha256 TEXT NOT NULL,
          checkedAt REAL NOT NULL
        )
        """).execute(db)
    }
    return database
  }

  private func temporaryDirectory() -> URL {
    return FileManager.default.temporaryDirectory
      .appendingPathComponent("festicore-sqlite-pack-\(UUID().uuidString)", isDirectory: true)
  }
}
