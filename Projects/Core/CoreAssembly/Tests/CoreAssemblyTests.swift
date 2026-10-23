//
//  CoreAssemblyTests.swift
//  CoreAssemblyTests
//
//  Created by FestiCore on 10/23/26.
//

import Testing
import FestiCoreNetworkInterface
import FestiCoreStorageInterface
@testable import CoreAssembly

@Suite("CoreAssembly")
struct CoreAssemblyTests {
  @Test("인증 없는 네트워크 클라이언트를 생성한다")
  func plainClient() {
    let client: any FestiCoreNetworkClient = NetworkAssembly.plainClient()
    #expect(String(describing: type(of: client)).isEmpty == false)
  }

  @Test("보안 저장소를 생성한다")
  func secureStorage() {
    let storage: any SecureStorage = StorageAssembly.secureStorage()
    #expect(String(describing: type(of: storage)) == "KeychainStorage")
  }
}
