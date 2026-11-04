//
//  AppDatabaseMigrator.swift
//  FestiCoreStorage
//
//  Created by FestiCore on 10/22/26.
//

import SQLiteData

enum AppDatabaseMigrator {
  static func migrate(_ database: any DatabaseWriter) throws {
    var migrator = DatabaseMigrator()
    migrator.registerMigration("2026-10-22-create-shared-values") { db in
      try #sql(
        """
        CREATE TABLE IF NOT EXISTS sharedValues (
          key TEXT PRIMARY KEY NOT NULL,
          value BLOB NOT NULL
        )
        """
      ).execute(db)
    }
    migrator.registerMigration("2026-11-04-create-cached-festival-packs") { db in
      try #sql(
        """
        CREATE TABLE IF NOT EXISTS cachedFestivalPacks (
          festivalID TEXT PRIMARY KEY NOT NULL,
          packVersion INTEGER NOT NULL,
          etag TEXT NOT NULL,
          pack BLOB NOT NULL,
          sha256 TEXT NOT NULL,
          checkedAt REAL NOT NULL
        )
        """
      ).execute(db)
    }
    try migrator.migrate(database)
  }
}
