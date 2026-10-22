//
//  SharedValueStorageTests.swift
//  FestiCoreStorageTests
//
//  Created by FestiCore on 10/22/26.
//

import Foundation
import Testing

@testable import FestiCoreStorage
import FestiCoreStorageInterface

@Suite("SharedValueStorage")
struct SharedValueStorageTests {
  @Test
  func 팩터리_저장소는_값을_저장하고_삭제한다() throws {
    let storage: any SharedValueStorage = StorageFactory.sharedValueStorage
    let key = UUID().uuidString
    let data = Data("value".utf8)

    try storage.save(data, forKey: key)
    #expect(try storage.load(forKey: key) == data)
    try storage.remove(forKey: key)
    #expect(try storage.load(forKey: key) == nil)
  }

  @Test
  func 메모리_저장소는_값을_저장하고_삭제한다() throws {
    let storage = VolatileSharedValueStorage()
    let data = Data("value".utf8)

    try storage.save(data, forKey: "sample")
    #expect(try storage.load(forKey: "sample") == data)
    try storage.remove(forKey: "sample")
    #expect(try storage.load(forKey: "sample") == nil)
  }
}
