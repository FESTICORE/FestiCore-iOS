//
//  StorageFactoryTests.swift
//  FestiCoreStorageTests
//
//  Created by FestiCore on 10/22/26.
//

import Testing
import Dependencies
import SQLiteData

@testable import FestiCoreStorage
import FestiCoreStorageInterface

@Suite("StorageFactory")
struct StorageFactoryTests {
  @Test("앱 저장소가 Attendance와 같이 공용 SQLite DB를 주입한다")
  func databaseRegistrationExposesAppDatabase() {
    var values = DependencyValues()
    StorageFactory.register(into: &values)

    #expect(values.appDatabase != nil)
    #expect(values.appDatabase === StorageFactory.databaseWriter)
  }

  @Test("영구 DB 실패 시 임시 DB를 팩 영구 저장소로 표시하지 않는다")
  func fallbackDatabaseIsNotPersistent() throws {
    enum PrimaryFailure: Error { case unavailable }
    let prepared = StorageFactory.prepareDatabaseResult(
      primary: { throw PrimaryFailure.unavailable },
      fallback: { try DatabaseQueue() },
      migrate: { _ in }
    )

    #expect(prepared.writer != nil)
    #expect(!prepared.isPersistent)
  }

  @Test
  func secureStorage를_생성한다() {
    let storage: any SecureStorage = StorageFactory.secureStorage
    #expect(String(describing: type(of: storage)) == "KeychainStorage")
  }

}

@Suite("SecureStorageKey")
struct SecureStorageKeyTests {
  @Test
  func 토큰_키를_각각_보유한다() {
    #expect(SecureStorageKey.accessToken.rawValue == "ACCESS_TOKEN")
    #expect(SecureStorageKey.refreshToken.rawValue == "REFRESH_TOKEN")
    #expect(SecureStorageKey.credentialIntegrity.rawValue == "CREDENTIAL_INTEGRITY")
    #expect(SecureStorageKey.apnsToken.rawValue == "APNS_DEVICE_TOKEN")
    #expect(!SecureStorageKey.all.contains(.apnsToken))
    #expect(Set(SecureStorageKey.all) == [.accessToken, .refreshToken, .credentialIntegrity, .sessionUserID])
  }
}
