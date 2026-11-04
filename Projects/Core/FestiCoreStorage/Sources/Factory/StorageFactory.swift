//
//  StorageFactory.swift
//  FestiCoreStorage
//
//  Created by FestiCore on 10/22/26.
//

import OSLog

import FestiCoreStorageInterface
import Dependencies
import SQLiteData

public enum StorageFactory {
  private static let liveDatabase = prepareDatabaseResult(context: .live)
  private static let previewDatabase = prepareDatabaseResult(context: .preview)
  private static let testDatabase = prepareDatabaseResult(context: .test)

  private static var preparedDatabase: (writer: (any DatabaseWriter)?, isPersistent: Bool) {
    // 의존성 캐시와 전역 초기화의 잠금 순서가 뒤집히지 않도록 context를 먼저 읽는다.
    @Dependency(\.context) var context
    switch context {
    case .live:
      return liveDatabase
    case .preview:
      return previewDatabase
    case .test:
      return testDatabase
    }
  }

  static func prepareDatabaseResult(context: DependencyContext) -> (writer: (any DatabaseWriter)?, isPersistent: Bool) {
    return withDependencies {
      $0.context = context
    } operation: {
      return prepareDatabaseResult()
    }
  }

  private static var database: (any DatabaseWriter)? {
    return preparedDatabase.writer
  }

  static func prepareDatabase(
    primary: () throws -> any DatabaseWriter = { try SQLiteData.defaultDatabase() },
    fallback: () throws -> any DatabaseWriter = { try DatabaseQueue() },
    migrate: (any DatabaseWriter) throws -> Void = AppDatabaseMigrator.migrate
  ) -> (any DatabaseWriter)? {
    return prepareDatabaseResult(
      primary: primary,
      fallback: fallback,
      migrate: migrate
    ).writer
  }

  static func prepareDatabaseResult(
    primary: () throws -> any DatabaseWriter = { try SQLiteData.defaultDatabase() },
    fallback: () throws -> any DatabaseWriter = { try DatabaseQueue() },
    migrate: (any DatabaseWriter) throws -> Void = AppDatabaseMigrator.migrate
  ) -> (writer: (any DatabaseWriter)?, isPersistent: Bool) {
    do {
      let database = try primary()
      try migrate(database)
      return (database, true)
    } catch {
      Logger(subsystem: "io.festiCore.co", category: "storage")
        .fault("Failed to prepare app database: \(String(describing: error), privacy: .public)")
    }

    do {
      let database = try fallback()
      try migrate(database)
      return (database, false)
    } catch {
      Logger(subsystem: "io.festiCore.co", category: "storage")
        .fault("Failed to prepare in-memory database: \(String(describing: error), privacy: .public)")
      return (nil, false)
    }
  }

  public static var secureStorage: any SecureStorage {
    return KeychainStorage()
  }

  public static var sharedValueStorage: any SharedValueStorage {
    guard let database else { return VolatileSharedValueStorage() }
    return SQLiteSharedValueStorage(database: database)
  }

  public static var databaseWriter: (any DatabaseWriter)? {
    return database
  }

  /// 팩처럼 재시작 뒤에도 보존해야 하는 데이터에만 사용한다.
  public static var persistentDatabaseWriter: (any DatabaseWriter)? {
    return preparedDatabase.isPersistent ? preparedDatabase.writer : nil
  }

  public static func register(into values: inout DependencyValues) {
    if let database {
      values.defaultDatabase = database
      values.appDatabase = database
    }
    values.sharedValueStorage = sharedValueStorage
  }
}
