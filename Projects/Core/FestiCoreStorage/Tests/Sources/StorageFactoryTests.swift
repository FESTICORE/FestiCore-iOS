//
//  StorageFactoryTests.swift
//  FestiCoreStorageTests
//
//  Created by FestiCore on 10/22/26.
//

import Testing

@testable import FestiCoreStorage
import FestiCoreStorageInterface

@Suite("StorageFactory")
struct StorageFactoryTests {
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
    #expect(Set(SecureStorageKey.all) == [.accessToken, .refreshToken])
  }
}
