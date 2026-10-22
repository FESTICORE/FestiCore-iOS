//
//  SecureStorage.swift
//  FestiCoreStorageInterface
//
//  Created by FestiCore on 10/22/26.
//

public protocol SecureStorage: Sendable {
  func save(_ value: String, for key: SecureStorageKey) throws(SecureStorageError)
  func load(_ key: SecureStorageKey) throws(SecureStorageError) -> String?
  func remove(_ key: SecureStorageKey) throws(SecureStorageError)
  func removeAll() throws(SecureStorageError)
}
