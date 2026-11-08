//
//  AppearanceModeSharedKeyTests.swift
//  FestiCoreStorageTests
//
//  Created by FestiCore on 11/9/26.
//

import Dependencies
import Foundation
import Sharing
import Testing

@testable import FestiCoreStorage
import FestiCoreStorageInterface

/// 화면 모드는 영속 저장소에 두고, 이전 appStorage 선택을 처음 읽을 때 옮긴다.
@Suite("화면 모드 저장 키")
struct AppearanceModeSharedKeyTests {
  @Test("이전 appStorage 선택을 처음 읽을 때 영속 저장소로 옮긴다")
  func migratesLegacyValue() throws {
    let storage = VolatileSharedValueStorage()
    withDependencies {
      $0.context = .live
      $0.sharedValueStorage = storage
    } operation: {
      @SharedReader(.appearanceMode(legacyValue: { "light" })) var mode
      #expect(mode == "light")
    }
    let saved = try #require(try storage.load(forKey: "FestiCore.appearanceMode"))
    #expect(try JSONDecoder().decode(
      String.self,
      from: saved
    ) == "light")
  }

  @Test("영속 저장소에 값이 있으면 이전 값보다 그것을 쓴다")
  func prefersStoredValue() throws {
    let storage = VolatileSharedValueStorage()
    try storage.save(
      JSONEncoder().encode("system"),
      forKey: "FestiCore.appearanceMode"
    )
    withDependencies {
      $0.context = .live
      $0.sharedValueStorage = storage
    } operation: {
      @SharedReader(.appearanceMode(legacyValue: { "light" })) var mode
      #expect(mode == "system")
    }
  }

  @Test("이전 값도 없으면 지금까지처럼 다크다")
  func defaultsToDark() {
    withDependencies {
      $0.context = .live
      $0.sharedValueStorage = VolatileSharedValueStorage()
    } operation: {
      @SharedReader(.appearanceMode(legacyValue: { nil })) var mode
      #expect(mode == "dark")
    }
  }
}
