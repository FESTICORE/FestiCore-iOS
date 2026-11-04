import SQLiteData
import Testing
@testable import FestiCoreStorage

@Suite("팩 캐시 DB 마이그레이션")
struct PackDatabaseMigrationTests {
  @Test("팩 테이블 생성은 기존 sharedValues와 반복 실행을 보존한다")
  func createsPackTableWithoutResettingSharedValues() throws {
    let database = try DatabaseQueue()
    try AppDatabaseMigrator.migrate(database)
    try database.write { db in
      try #sql("INSERT INTO sharedValues VALUES ('existing', X'01')").execute(db)
      try #sql("""
        INSERT INTO cachedFestivalPacks
        (festivalID, packVersion, etag, pack, sha256, checkedAt)
        VALUES ('fst_example', 1, 'etag', X'01', 'sha', 1800000000)
        """).execute(db)
    }

    try AppDatabaseMigrator.migrate(database)

    let counts = try database.read { db in
      let shared = try #sql("SELECT COUNT(*) FROM sharedValues", as: Int.self).fetchOne(db)
      let packs = try #sql("SELECT COUNT(*) FROM cachedFestivalPacks", as: Int.self).fetchOne(db)
      return (shared, packs)
    }
    #expect(counts.0 == 1)
    #expect(counts.1 == 1)
  }
}
