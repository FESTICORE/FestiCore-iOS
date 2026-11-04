//
//  StorageFactoryTests.swift
//  FestiCoreStorageTests
//
//  Created by FestiCore on 10/22/26.
//

import Dispatch
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

  @Test("DB 초기화는 다른 스레드가 보유한 의존성 캐시 잠금을 다시 요청하지 않는다")
  func databaseInitializationDoesNotWaitForDependencyCache() {
    let values = DependencyValues()
    let lockQueue = DispatchQueue(label: "storage-test.dependency-lock")
    let databaseQueue = DispatchQueue(label: "storage-test.database")
    let databaseFinished = DispatchSemaphore(value: 0)

    lockQueue.async {
      _ = values[StorageLockProbe.self]
    }
    let acquired = StorageLockProbe.acquired.wait(timeout: .now() + 5)
    defer {
      StorageLockProbe.release.signal()
      lockQueue.sync {}
      databaseQueue.sync {}
    }
    #expect(acquired == .success)
    guard acquired == .success else { return }

    databaseQueue.async {
      withDependencies {
        $0 = values
      } operation: {
        let prepared = StorageFactory.prepareDatabaseResult(context: .test)
        #expect(prepared.writer != nil)
      }
      databaseFinished.signal()
    }
    #expect(databaseFinished.wait(timeout: .now() + 5) == .success)
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

private enum StorageLockProbe: DependencyKey {
  static let acquired = DispatchSemaphore(value: 0)
  static let release = DispatchSemaphore(value: 0)

  static var liveValue: Int {
    acquired.signal()
    _ = release.wait(timeout: .now() + 15)
    return 0
  }

  static var testValue: Int { return liveValue }
}
